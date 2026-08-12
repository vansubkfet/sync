VietQR hiện có Public Access và documentation nói rõ:

Sử dụng ngay các API của VietQR.io mà không cần đăng ký.

Public Access là miễn phí.

Và Tax ID Lookup API hiện tại là:

GET https://api.vietqr.io/v2/business/{taxCode}

Documentation hiện tại cho thấy response dạng:
{
  "code": "00",
  "desc": "Success - Thành công",
  "data": {
    "id": "0316794479",
    "name": "CÔNG TY TNHH CASSO",
    "internationalName": "CASSO COMPANY LIMITED",
    "shortName": "CASSO",
    "address": "...",
    "status" : "...",
  },
  "metadata":{
    "disclaimer":"...",
    "source":"https://www.gdt.gov.vn",
    "updatedAt":"...",
    "contact":"..."
  }
}

output when test with curl:
C:\Users\bkfet>curl "https://api.vietqr.io/v2/business/0101248141"
{"code":"00","desc":"Success - Thành công","data":{"id":"0101248141","name":"CÔNG TY CỔ PHẦN FPT","internationalName":"FPT CORPORATION","shortName":"FPT CORP","address":"Số 10 phố Phạm Văn Bạch, Phường Cầu Giấy, TP Hà Nội","status":"NNT đang hoạt động"},"metadata":{"disclaimer":"Dữ liệu tổng hợp từ Trang thông tin điện tử của Cục Thuế 2 tháng trước","source":"https://www.gdt.gov.vn","updatedAt":"2026-06-22T05:33:26.000Z","contact":"idkit@cas.so"}}
C:\Users\bkfet>curl "https://api.vietqr.io/v2/business/0107993939"
{"code":"00","desc":"Success - Thành công","data":{"id":"0107993939","name":"CÔNG TY TNHH THƯƠNG MẠI MỘC AN","internationalName":"MOC AN TRADING COMPANY LIMITED","shortName":"MOC AN TRADING CO.,LTD","address":"Tầng 1, Tòa nhà HH1, phố Dương Đình Nghệ, Phường Cầu Giấy, TP Hà Nội","status":"NNT đang hoạt động"},"metadata":{"disclaimer":"Dữ liệu tổng hợp từ Trang thông tin điện tử của Cục Thuế 3 ngày trước","source":"https://www.gdt.gov.vn","updatedAt":"2026-08-08T20:11:18.000Z","contact":"idkit@cas.so"}}
C:\Users\bkfet>
