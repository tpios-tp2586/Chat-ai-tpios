# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trên `main`; tuyệt đối không tự tạo/chuyển branch.
- HEAD trước lần cập nhật checkpoint này: `e09b99bb0b74b3941023bd103b2da1584a3ccb7b` — `Record Ara resize state compile fix`.
- Checkpoint này là trạng thái hiện tại, không phải nhật ký; lịch sử nằm trong Git commits/diffs.

## Quy tắc bắt buộc
- Trước khi sửa code: kiểm tra HEAD và đọc code thực tế đúng phạm vi; không đoán.
- Thay đổi tối thiểu, không thêm dependency nếu không cần (Ponytail).
- Bảo vệ chatbot/API, chat history, voice pipeline, Text Chat và Chibi Chat. Không sửa các phần này khi làm Ara.
- Không tạo branch; không tự chạy/dispatch GitHub Actions hoặc Codemagic. Người dùng tự chạy build thủ công.
- Codemagic chỉ xuất IPA; không thêm ZIP artifact ngoài yêu cầu.
- Không sửa backup file/workflow. Người dùng thao tác chủ yếu trên iPhone; báo kết quả ngắn gọn, rõ ràng.

## Hướng hiện tại
- Tiếp tục Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Không quay lại phương án 8 ảnh biểu cảm thay cho avatar 3D.
- Ara đã load và phát animation trên iPhone ở các lần build trước; cần đánh giá bằng quan sát thực tế, không chỉ dựa vào log.
- Không thay đổi chatbot hoặc voice pipeline để xử lý animation/UI test.

## Ara test panel — trạng thái đã xác nhận
- Người dùng đã chạy Codemagic và xác nhận **build thành công** với các thay đổi gần nhất.
- Tuy nhiên **UI chưa đạt yêu cầu sử dụng**:
  - Di chuyển/kéo khung vẫn bị lag, không mượt.
  - Thu phóng khung vẫn lag và khó thao tác.
- Vì vậy không được đánh dấu panel hoàn tất chỉ vì build thành công.
- Các commit trước đã đặt thao tác kéo ở header, đưa nút resize/thu gọn vào header và thêm state cho resize. Những thay đổi đó chưa giải quyết được trải nghiệm thực tế.
- Chưa có sửa code mới sau phản hồi này.

## Việc tiếp theo
1. Kiểm tra HEAD mới nhất trên `main`, sau đó đọc đúng Swift view/state/gesture đang điều khiển Ara test panel.
2. Xác định nguyên nhân gây giật ở drag và resize từ code thực tế; tránh tiếp tục chồng thêm gesture/state hoặc sửa mò.
3. Ưu tiên đơn giản hóa tương tác và giảm cập nhật layout/state không cần thiết; giữ thao tác kéo và resize dễ dùng, ổn định trên iPhone.
4. Chỉ sửa tối thiểu trong phạm vi panel. Không đụng chatbot, voice pipeline, Text Chat, Chibi Chat hay backup/workflow.
5. Người dùng chạy Codemagic và kiểm tra lại trên iPhone; chỉ kết luận đạt khi cả drag và resize đều mượt, dễ thao tác.

## Tiếp tục ở khung chat mới
Đọc file này trước, kiểm tra HEAD trên `main`, rồi kiểm tra code panel liên quan. Không cần đọc lại toàn bộ lịch sử hội thoại. Không tạo branch.
