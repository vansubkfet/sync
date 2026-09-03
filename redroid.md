guide me step by step to install redroid in linux server

Được. Với mục tiêu của bạn là chạy Google ML Kit OCR trên Linux server CPU-only, offline, tôi khuyên chúng ta triển khai ReDroid theo hướng POC trước, production sau. Không nên ngay lập tức tối ưu Kubernetes hay multi-instance.

ReDroid hiện hỗ trợ Android 12–16 và amd64/arm64; tài liệu upstream hiện tại dùng Docker + kernel Binder làm nền tảng.

Tôi sẽ hướng dẫn theo Ubuntu Linux x86_64 trước. Nếu server của bạn là Ubuntu 22.04/24.04 thì càng tốt.

1. Kiến trúc chúng ta sẽ dựng

Mục tiêu cuối cùng:

Linux Server
│
├── Docker
│
├── Linux Kernel
│    └── Binder / BinderFS
│
└── ReDroid Container
     │
     ├── Android OS
     ├── ADB
     └── ML Kit OCR App
             │
             └── Google ML Kit

Sau khi hoàn thành bước đầu, bạn sẽ có:

Linux
  │
  │ localhost:5555
  ▼
ReDroid
  │
  ▼
Android
  │
  ▼
ADB shell

Sau đó mới cài APK OCR của chúng ta:

Linux OCR Gateway
       │
       ▼
ReDroid Android
       │
       ▼
ML Kit
       │
       ▼
OCR JSON
2. Kiểm tra server trước

Chạy:

uname -a

và:

uname -m

Tôi kỳ vọng:

x86_64

Tiếp tục:

cat /etc/os-release

và:

docker --version

Nếu Docker chưa có thì kiểm tra:

which docker

Cuối cùng:

free -h

và:

nproc
Cấu hình tôi khuyến nghị cho POC
CPU:    >= 4 cores
RAM:    >= 8 GB
Disk:   >= 20 GB
OS:     Ubuntu 22.04/24.04 x86_64
GPU:    không cần

Đối với ML Kit OCR, chúng ta sẽ benchmark CPU/RAM thực tế sau.

3. Cài Docker

Nếu server chưa có Docker:

sudo apt update
sudo apt install -y docker.io

Enable:

sudo systemctl enable docker
sudo systemctl start docker

Kiểm tra:

docker --version

Ví dụ:

Docker version 28.x.x

Test:

sudo docker run --rm hello-world

Nếu thấy:

Hello from Docker!

thì Docker OK.

4. Kiểm tra Linux kernel có Binder hay chưa

Đây là bước quan trọng nhất.

ReDroid không đơn thuần là một Docker container thông thường. Android cần Linux Binder IPC để hoạt động.

Tài liệu ReDroid hiện tại yêu cầu kernel có Binder/BinderFS; trên Ubuntu, hướng dẫn quick-start sử dụng binder_linux.

Kiểm tra:

grep CONFIG_ANDROID_BINDER /boot/config-$(uname -r)

Bạn muốn thấy đại loại:

CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y

hoặc module:

CONFIG_ANDROID_BINDER_IPC=m

Kiểm tra module:

lsmod | grep binder

Nếu chưa có gì, thử:

sudo modprobe binder_linux

Sau đó:

lsmod | grep binder
5. Cài kernel modules cần thiết

Trên Ubuntu, thử:

sudo apt install -y linux-modules-extra-$(uname -r)

Sau đó:

sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"

Kiểm tra:

ls -l /dev/binder*

Bạn có thể thấy:

/dev/binder
/dev/hwbinder
/dev/vndbinder

Nếu thấy được chúng → rất tốt.

6. Kiểm tra Binder

Chạy:

ls -l /dev/binder
ls -l /dev/hwbinder
ls -l /dev/vndbinder

Sau đó:

ls -l /dev/binderfs

Nếu server đã dùng BinderFS thì cấu trúc có thể khác.

Điểm quan trọng là:

Binder IPC
   ↓
Linux kernel
   ↓
ReDroid

phải hoạt động.

7. Làm cho Binder tự load sau reboot

Không nên chỉ chạy:

modprobe binder_linux

vì sau reboot module có thể biến mất.

Tạo:

sudo nano /etc/modules-load.d/redroid.conf

Nội dung:

binder_linux

Sau đó:

sudo nano /etc/modprobe.d/redroid.conf

Nội dung:

options binder_linux devices=binder,hwbinder,vndbinder

Reload:

sudo modprobe -r binder_linux

rồi:

sudo modprobe binder_linux

Kiểm tra:

ls -l /dev/binder*
8. Cài ADB

Chúng ta cần ADB để debug ReDroid và cài APK.

sudo apt install -y adb

Kiểm tra:

adb version

Ví dụ:

Android Debug Bridge version 1.0.41
9. Chọn Android version cho ReDroid

Ở thời điểm hiện tại ReDroid upstream đang cung cấp các image Android 12, 13, 14, 15 và 16, bao gồm các image 64only.

Cho ML Kit POC, tôi đề xuất:

Android 14
x86_64 / 64-bit

Tức:

redroid/redroid:14.0.0_64only-latest

Tại sao chưa chọn Android 16?

Không phải vì Android 16 không tốt. Mà vì mục tiêu đầu tiên của chúng ta là:

tạo môi trường ổn định để kiểm tra ML Kit

chứ chưa phải chạy Android mới nhất.

Sau khi ML Kit chạy ổn, chúng ta có thể benchmark Android 14 vs 15 vs 16.

10. Pull image

Chạy:

sudo docker pull redroid/redroid:14.0.0_64only-latest

Kiểm tra:

sudo docker images | grep redroid

Bạn sẽ thấy:

redroid/redroid
14.0.0_64only-latest
11. Tạo thư mục persistent data

Không nên để data Android nằm hoàn toàn trong writable container layer.

Tạo:

mkdir -p ~/redroid-data

Kiểm tra:

ls -ld ~/redroid-data
12. Chạy ReDroid lần đầu

Đây là command POC quan trọng:

sudo docker run -itd \
  --privileged \
  --name redroid \
  -v ~/redroid-data:/data \
  -p 127.0.0.1:5555:5555 \
  redroid/redroid:14.0.0_64only-latest

Tôi cố tình dùng:

127.0.0.1:5555

thay vì:

0.0.0.0:5555

vì không được expose ADB 5555 ra Internet/public network. Chính tài liệu ReDroid cũng cảnh báo điều này.

13. Kiểm tra container
sudo docker ps

Bạn muốn thấy:

CONTAINER ID
IMAGE
STATUS
PORTS
NAMES

xxxx
redroid/redroid:14.0.0_64only-latest
Up ...
127.0.0.1:5555->5555/tcp
redroid
14. Xem log Android

Đây là command bạn sẽ dùng rất nhiều:

sudo docker logs -f redroid

Nếu container chạy bình thường, Android sẽ bắt đầu boot.

Nếu container chết:

sudo docker ps -a

sau đó:

sudo docker logs redroid

ReDroid upstream cũng khuyến nghị xem docker logs, logcat và dmesg khi container biến mất hoặc ADB không connect được.

15. Connect bằng ADB

Chờ khoảng vài chục giây rồi:

adb connect 127.0.0.1:5555

Kết quả mong muốn:

connected to 127.0.0.1:5555

Sau đó:

adb devices

Bạn muốn thấy:

List of devices attached
127.0.0.1:5555    device

Nếu thấy:

offline

thì Android chưa boot hoàn toàn.

16. Kiểm tra Android

Chạy:

adb -s 127.0.0.1:5555 shell getprop ro.build.version.release

Expected:

14

Kiểm tra API:

adb -s 127.0.0.1:5555 shell getprop ro.build.version.sdk

Expected:

34

Kiểm tra architecture:

adb -s 127.0.0.1:5555 shell getprop ro.product.cpu.abi

Tôi kỳ vọng:

x86_64

Đây là một kiểm tra rất quan trọng đối với ML Kit.

17. Kiểm tra Android đã boot hoàn toàn
adb -s 127.0.0.1:5555 shell getprop sys.boot_completed

Phải trả về:

1

Bạn cũng có thể:

adb -s 127.0.0.1:5555 shell

sau đó:

getprop

Thoát:

exit
18. Kiểm tra CPU/RAM của ReDroid

Trên host:

sudo docker stats redroid

Bạn sẽ thấy dạng:

CPU %
MEM USAGE / LIMIT
MEM %
NET I/O
BLOCK I/O
PIDS

Đây sẽ là baseline rất quan trọng cho project OCR.

Ví dụ chúng ta sẽ đo:

Idle:
    CPU = ?
    RAM = ?

OCR 1 request:
    CPU = ?
    RAM = ?

OCR 4 concurrent:
    CPU = ?
    RAM = ?
19. Kiểm tra Android process
adb -s 127.0.0.1:5555 shell ps -A

Hoặc:

adb -s 127.0.0.1:5555 shell top -n 1
20. Kiểm tra có Google Play Services hay không

Đây là điểm rất quan trọng đối với kế hoạch ML Kit của chúng ta.

Chạy:

adb -s 127.0.0.1:5555 shell pm list packages | grep google

Ví dụ:

package:com.google.android.gms
package:com.google.android.gsf
...

hoặc không có gì.

Đừng lo nếu không có Google Play Services.

Thiết kế của chúng ta sẽ cố gắng dùng bundled ML Kit:

implementation("com.google.mlkit:text-recognition:...")

thay vì:

implementation("com.google.android.gms:play-services-mlkit-text-recognition:...")

Mục tiêu là model được đóng vào APK để server có thể chạy offline.

Đây là một trong những lý do tôi muốn chúng ta kiểm tra ML Kit ngay trên ReDroid thay vì giả định rằng nó chắc chắn hoạt động.

21. Kiểm tra ADB install APK

Trước khi làm OCR app, hãy test khả năng cài APK.

Bạn có thể lấy một APK test bất kỳ phù hợp với x86_64:

adb -s 127.0.0.1:5555 install app-debug.apk

Sau đó:

adb -s 127.0.0.1:5555 shell pm list packages

Nếu package xuất hiện:

package:com.example.test

thì pipeline:

Linux
 ↓
ADB
 ↓
ReDroid
 ↓
Android
 ↓
APK

đã hoạt động.

22. Nhưng có một vấn đề lớn: ML Kit + x86_64

Đây là phần tôi muốn bạn đặc biệt chú ý.

Chúng ta không chỉ cần:

ReDroid chạy được

mà cần:

ReDroid
   ↓
Android x86_64
   ↓
ML Kit native libraries
   ↓
Text Recognition
   ↓
OCR output

ML Kit có native components.

Vì vậy, không được kết luận rằng ReDroid chạy được = ML Kit chạy được.

Chúng ta phải test APK thật.

Nếu APK ML Kit gặp lỗi kiểu:

UnsatisfiedLinkError

hoặc:

dlopen failed

hoặc:

ABI not supported

thì chúng ta sẽ phải xử lý ABI/native bridge.

Đây chính là lý do tôi khuyên:

Android Emulator
       ↓
reference implementation
       ↓
ReDroid

thay vì ngay từ đầu production hóa ReDroid.

23. Đừng bật ADB public

Tuyệt đối tránh:

-p 5555:5555

trên server production nếu firewall/network cho phép Internet truy cập.

Thay bằng:

-p 127.0.0.1:5555:5555

Sau đó nếu máy khác cần debug:

Developer PC
     │
     │ SSH tunnel
     ▼
Linux Server
     │
     ▼
127.0.0.1:5555
     │
     ▼
ReDroid

Ví dụ:

ssh -L 5555:127.0.0.1:5555 user@server

trên PC của bạn.

Sau đó PC:

adb connect 127.0.0.1:5555

Tài liệu ReDroid cũng cảnh báo không expose ADB trực tiếp ra public network.

24. Nếu bước modprobe thất bại

Đây là lỗi có khả năng cao nhất.

Ví dụ:

sudo modprobe binder_linux

trả:

modprobe: FATAL: Module binder_linux not found

Đừng tiếp tục chạy Docker.

Hãy gửi tôi output của:

uname -a
cat /etc/os-release
uname -r
grep CONFIG_ANDROID_BINDER /boot/config-$(uname -r)
ls /lib/modules/$(uname -r)
ls -l /dev/binder*

Từ đó tôi sẽ xác định chính xác kernel của bạn đang thiếu gì.

25. Nếu container tự biến mất

Chạy:

sudo docker ps -a

sau đó:

sudo docker logs redroid

và:

dmesg -T | tail -100

ReDroid docs cũng chỉ ra rằng container biến mất thường liên quan tới kernel modules và khuyến nghị kiểm tra dmesg.

26. Sau khi POC chạy được, chúng ta sẽ không dùng command trên cho production

Command:

docker run -itd \
  --privileged \
  --name redroid \
  ...

chỉ nên coi là bootstrap/POC.

Production architecture của chúng ta sẽ là:

                         Linux Server
┌──────────────────────────────────────────────────────┐
│                                                      │
│                 OCR Gateway                         │
│             FastAPI / gRPC                          │
│                    │                                 │
│                    ▼                                 │
│              Worker Pool                            │
│                    │                                 │
│          ┌─────────┼─────────┐                       │
│          ▼         ▼         ▼                       │
│       ReDroid   ReDroid   ReDroid                   │
│       Worker 1  Worker 2  Worker 3                  │
│          │         │         │                       │
│          ▼         ▼         ▼                       │
│       ML Kit    ML Kit    ML Kit                    │
│                                                      │
└──────────────────────────────────────────────────────┘

Ví dụ:

POST /v1/ocr
       │
       ▼
OCR Gateway
       │
       ├── Worker 1 busy
       ├── Worker 2 available ──────► ML Kit
       └── Worker 3 busy

ADB chỉ dùng cho:

install APK
debug
health/recovery

Không dùng ADB làm OCR data plane.

27. Và cuối cùng chúng ta sẽ thêm Nexus

Vì server của bạn không có Internet, production flow sẽ là:

                    Internet environment
                           │
                           ▼
                    Build Android APK
                           │
                    ML Kit bundled
                           │
                           ▼
                         Nexus
                     ┌─────┴─────┐
                     │           │
                   APK        Docker image
                     │           │
                     └─────┬─────┘
                           │
                           ▼
                   Offline Linux
                           │
                     ReDroid
                           │
                     ML Kit OCR

Điểm quan trọng là không cần runtime download model từ Google nếu chúng ta dùng đúng bundled ML Kit artifact và đóng model vào APK. Sau này tôi sẽ hướng dẫn riêng phần Nexus/Gradle/offline build để đảm bảo điều này.

Việc bạn nên làm ngay bây giờ

Đừng chạy toàn bộ một lúc. Hãy chạy 6 command kiểm tra host này trước:

uname -m
cat /etc/os-release
uname -r
docker --version
grep CONFIG_ANDROID_BINDER /boot/config-$(uname -r)
ls -l /dev/binder* 2>/dev/null

Paste nguyên output 6 command đó cho tôi.

Tôi sẽ dựa đúng vào kernel/OS của server bạn để dẫn bạn qua bước 1 → Binder → Docker → ReDroid → ADB → Android → cài ML Kit APK, thay vì bắt bạn chạy một tutorial Ubuntu chung chung.

đây là output:
uname -m : x86_64
uname -a: Linux  6.12.0-1.23.3..2.el9uel.x86_64 
cat /etc/os-release: oracle linux server, Version 9.6
nproc: 14

Thông tin này rất hữu ích. Server của bạn khá phù hợp để chạy ReDroid:

Architecture : x86_64        ✅
OS           : Oracle Linux 9.6
Kernel       : 6.12.0-1.23.3..2.el9uel.x86_64
CPU          : 14 cores      ✅
GPU          : không cần cho POC

ReDroid upstream nói rằng nó có thể chạy trên Linux nói chung miễn kernel có các tính năng cần thiết, không giới hạn Ubuntu. Tuy nhiên hướng dẫn chính thức chủ yếu minh họa Ubuntu, nên với Oracle Linux 9.6 chúng ta cần kiểm tra kernel trước khi cài gì thêm.

Đặc biệt, tôi không muốn bạn chạy apt install linux-modules-extra... như hướng dẫn Ubuntu trước đó, vì Oracle Linux dùng hệ RPM/dnf và kernel EL9. Với server của bạn, chúng ta sẽ kiểm tra chính xác kernel trước.

Bước tiếp theo — kiểm tra Binder

Hãy chạy nguyên khối command này:

echo "===== OS ====="
cat /etc/os-release

echo
echo "===== KERNEL ====="
uname -r

echo
echo "===== ARCH ====="
uname -m

echo
echo "===== BINDER CONFIG ====="
grep -E 'CONFIG_ANDROID_BINDER|CONFIG_ANDROID_BINDERFS' \
    /boot/config-$(uname -r) 2>/dev/null || true

echo
echo "===== BINDER FILESYSTEM ====="
grep binder /proc/filesystems || true

echo
echo "===== BINDER MODULE ====="
lsmod | grep binder || true

echo
echo "===== BINDER DEVICE ====="
ls -la /dev/binder* 2>/dev/null || true

echo
echo "===== BINDERFS ====="
ls -la /dev/binderfs 2>/dev/null || true

echo
echo "===== ASHMEM ====="
grep ashmem /proc/misc || true

echo
echo "===== DOCKER ====="
docker --version 2>&1 || true

echo
echo "===== DOCKER INFO ====="
docker info 2>&1 | head -40
Tại sao tôi muốn kiểm tra từng thứ này?

ReDroid cần Binder IPC. Documentation hiện tại vẫn hướng dẫn load:

modprobe binder_linux devices="binder,hwbinder,vndbinder"

và với các Android version cũ hơn còn có ashmem_linux; các bản Android mới hơn không còn cần ashmem theo tài liệu mới của ReDroid.

Chúng ta cần xác định server của bạn đang ở một trong các trạng thái:

A. Binder đã có sẵn
        ↓
   rất tốt → chạy ReDroid

B. Kernel có Binder nhưng chưa load
        ↓
   modprobe → chạy ReDroid

C. Kernel có BinderFS nhưng topology khác
        ↓
   cấu hình BinderFS

D. Kernel hoàn toàn không có Binder
        ↓
   phải cài kernel module/KMP tương ứng Oracle Linux

Đừng tự cài kernel mới hoặc DKMS lúc này. Kernel của bạn là 6.12.0-...el9uel, khá mới; trước tiên phải xem chính xác nó đã có Binder chưa.

Một điểm nữa: Oracle Linux 9.6 + Docker

Nếu docker info chạy bình thường thì chúng ta có thể tiếp tục.

Nếu chưa có Docker, đừng vội cài docker.io bằng apt — Oracle Linux nên đi theo Docker CE/RPM hoặc Podman tùy môi trường enterprise.

Sau bước này chúng ta sẽ đi theo pipeline này

Tôi đề xuất không nhảy thẳng vào ML Kit:

STEP 1
Oracle Linux kernel
        ↓
STEP 2
Binder
        ↓
STEP 3
Docker
        ↓
STEP 4
ReDroid Android 14 x86_64
        ↓
STEP 5
ADB
        ↓
STEP 6
Android boot_completed = 1
        ↓
STEP 7
Install một APK test
        ↓
STEP 8
Install ML Kit OCR APK
        ↓
STEP 9
Offline OCR test
        ↓
STEP 10
Benchmark CPU/RAM/latency
        ↓
STEP 11
Multiple ReDroid workers
        ↓
STEP 12
OCR Gateway

Với 14 CPU cores, sau khi single-instance chạy ổn, chúng ta có cơ sở rất tốt để thử:

ReDroid #1 ── ML Kit
ReDroid #2 ── ML Kit
ReDroid #3 ── ML Kit
ReDroid #4 ── ML Kit
       ...

rồi benchmark xem một instance ML Kit OCR thực sự tiêu thụ bao nhiêu CPU/RAM trước khi quyết định số worker.

Lưu ý về Android version

ReDroid hiện đã có cả Android 14/15/16 và các image 64only; upstream hiện còn liệt kê Android 17 trong nhánh mới hơn.

Nhưng tôi vẫn muốn bắt đầu với Android 14 64only cho ML Kit POC:

redroid/redroid:14.0.0_64only-latest

không phải vì Android 14 là bản mới nhất, mà vì chúng ta cần một baseline ổn định trước khi tối ưu.

Gửi tôi output của block command trên. Sau đó tôi sẽ đưa cho bạn chính xác các command dành cho Oracle Linux 9.6, bắt đầu từ Binder — không dùng các lệnh Ubuntu một cách máy móc.
