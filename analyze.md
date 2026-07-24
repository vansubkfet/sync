Lỗi:

Cannot read properties of undefined (reading 'stop_reason')

khi gọi Anthropic-compatible endpoint ở streaming mode gần như chắc chắn không phải là lỗi của SDK, mà là endpoint của bạn trả về stream không đúng Anthropic SSE protocol.

Claude SDK mong đợi điều gì?

Trong streaming mode (stream=true), Anthropic SDK mong đợi chuỗi event như sau:

event: message_start
data: {
  "type":"message_start",
  "message":{
      "id":"msg_xxx",
      "type":"message",
      "role":"assistant",
      "content":[],
      "model":"..."
  }
}

event: content_block_start
...

event: content_block_delta
...

event: content_block_stop
...

event: message_delta
data:{
   "type":"message_delta",
   "delta":{
      "stop_reason":"end_turn",
      "stop_sequence":null
   }
}

event: message_stop
data:{
   "type":"message_stop"
}

Cuối stream SDK sẽ đọc

event.delta.stop_reason

hoặc

message.stop_reason

tùy version.

Nếu event này không tồn tại thì sẽ xuất hiện

Cannot read properties of undefined
(reading 'stop_reason')
Những nguyên nhân thường gặp
1. Thiếu message_delta

Nhiều server chỉ stream token:

content_block_delta

content_block_delta

content_block_delta

message_stop

mà không gửi

message_delta

=> SDK crash.

2. message_delta không có delta

Sai:

{
  "type":"message_delta"
}

Đúng:

{
  "type":"message_delta",
  "delta":{
      "stop_reason":"end_turn",
      "stop_sequence":null
  }
}
3. message_start không đúng format

Sai:

{
 "type":"message_start"
}

Đúng:

{
 "type":"message_start",
 "message":{
     "id":"msg_1",
     "type":"message",
     "role":"assistant",
     "content":[]
 }
}
4. Không gửi message_stop

SDK luôn mong đợi

message_stop

ở cuối.

5. OpenAI stream được convert chưa đầy đủ

Rất nhiều proxy chỉ convert

ChatCompletionChunk

thành

content_block_delta

nhưng quên convert finish_reason.

Ví dụ OpenAI trả

{
 "choices":[
   {
      "delta":{},
      "finish_reason":"stop"
   }
 ]
}

phải convert thành

event: message_delta

{
 "type":"message_delta",
 "delta":{
     "stop_reason":"end_turn",
     "stop_sequence":null
 }
}

event: message_stop
Nếu bạn đang làm Anthropic-compatible API

Cuối stream tối thiểu phải là

event: message_delta
data: {
  "type":"message_delta",
  "delta":{
      "stop_reason":"end_turn",
      "stop_sequence":null
  }
}

event: message_stop
data:{
  "type":"message_stop"
}
Cách debug nhanh

In toàn bộ SSE mà endpoint trả về.

Ví dụ:

event: message_start
data: ...

event: content_block_start
data: ...

event: content_block_delta
data: ...

...

Xem cuối stream có

message_delta

không.

99% lỗi này nằm ở đây.

Một nguyên nhân khác

Một số server trả

data: [DONE]

(theo OpenAI)

thay vì

event: message_stop

Anthropic SDK không hiểu [DONE].
