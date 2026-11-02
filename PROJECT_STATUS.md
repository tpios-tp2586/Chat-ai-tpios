# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trên `main`; tuyệt đối không tự tạo/chuyển branch.
- HEAD trước lần cập nhật checkpoint này: `2b2674f8837c45350981259adb917cf45207eda0` — `Simplify Ara test panel drag and resize gestures`.
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

## Ara test panel — implementation hiện tại
- Đã sửa trực tiếp trên `main` trong commit `2b2674f8837c45350981259adb917cf45207eda0` (`Simplify Ara test panel drag and resize gestures`).
- Drag: dùng vùng tay nắm riêng 32×28 pt ở đầu panel; vị trí kéo dùng `@GestureState`, clamp trong vùng màn hình và chỉ lưu X/Y khi kết thúc gesture. Nút thu gọn 60×60 pt cũng nhận drag để di chuyển.
- Resize: chuyển nút zoom xuống góc dưới bên phải bên trong panel, vùng chạm 44×44 pt; kéo một ngón tay. Delta dùng `@GestureState`, chỉ ghi `@AppStorage` một lần ở `.onEnded`, không ghi persistent state theo từng frame.
- Toàn bộ nội dung panel được scale cùng kích thước bằng `scaleEffect`; giới hạn scale 0.59–1.25. Mức nhỏ nhất cho chiều cao panel khoảng 121 pt (xấp xỉ gấp đôi nút Home ảo 60 pt).
- Thu gọn vẫn là nút 60×60 pt; vị trí tâm được giữ tương ứng khi đóng/mở. Hai nhóm animation và logic test hiện có được giữ nguyên.
- Đây mới là thay đổi code; **chưa có xác nhận build Codemagic hoặc kiểm thử thao tác trên iPhone cho commit mới**. Không đánh dấu hoàn tất trước khi người dùng xác nhận.

## Việc tiếp theo
1. Người dùng chạy Codemagic thủ công với HEAD hiện tại trên `main`.
2. Kiểm tra trên iPhone: kéo panel bằng tay nắm; kéo nút zoom ở góc dưới phải; kiểm tra chữ/nút/list cùng scale; thu gọn thành nút ảo rồi kéo nút đi nơi khác và mở lại.
3. Nếu build lỗi hoặc thao tác còn giật, lấy log/kết quả thực tế rồi mới sửa tiếp; không sửa mò.
4. Chỉ sửa phạm vi Ara test panel. Không đụng chatbot/API, chat history, voice pipeline, Text Chat, Chibi Chat hoặc backup/workflow.

## Tiếp tục ở khung chat mới
Đọc checkpoint này, kiểm tra HEAD trên `main`, rồi đối chiếu đúng code panel. Chờ kết quả build/test thực tế trước khi tuyên bố hoàn tất. Không tạo branch.
