# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trên `main`; tuyệt đối không tự tạo/chuyển branch.
- HEAD trước lần cập nhật checkpoint này: `7efaf7b93473e77b3f18367ff877168637a7aab4` — `Fix Ara panel overlay view builder inference`.
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
- Đã tách overlay Test Ara thành `AraTestPanelOverlay` trong commit `04b7411a8e76f1ab5345a1d737bfc1157e115633` (`Isolate Ara test panel gesture rendering`). `@GestureState` kéo/zoom nằm trong view con. Build tiếp theo báo lỗi generic inference ở `Group` trong helper; commit `7efaf7b93473e77b3f18367ff877168637a7aab4` thay `Group` bằng `ZStack` để SwiftUI xác định ViewBuilder rõ ràng.
- Giữ nguyên drag clamp, resize range 0.59–1.25, vùng kéo/zoom, collapse button và callback các animation test. Không thêm dependency.
- Drag: dùng vùng tay nắm riêng 32×28 pt ở đầu panel; vị trí kéo dùng `@GestureState`, clamp trong vùng màn hình và chỉ lưu X/Y khi kết thúc gesture. Nút thu gọn 60×60 pt cũng nhận drag để di chuyển.
- Resize: chuyển nút zoom xuống góc dưới bên phải bên trong panel, vùng chạm 44×44 pt; kéo một ngón tay. Delta dùng `@GestureState`, chỉ ghi `@AppStorage` một lần ở `.onEnded`, không ghi persistent state theo từng frame.
- Toàn bộ nội dung panel được scale cùng kích thước bằng `scaleEffect`; giới hạn scale 0.59–1.25. Mức nhỏ nhất cho chiều cao panel khoảng 121 pt (xấp xỉ gấp đôi nút Home ảo 60 pt).
- Thu gọn vẫn là nút 60×60 pt; vị trí tâm được giữ tương ứng khi đóng/mở. Hai nhóm animation và logic test hiện có được giữ nguyên.
- Người dùng xác nhận build và cài được bản trước, nhưng thao tác kéo/zoom/collapse gây treo hoặc giật. Bản tách gesture state có lỗi compile `Group` đã được sửa ở commit `7efaf7b93473e77b3f18367ff877168637a7aab4`; **chưa có kết quả build lại hoặc test iPhone cho commit này**. Không đánh dấu hoàn tất trước khi người dùng xác nhận.

## Việc tiếp theo
1. Người dùng chạy Codemagic thủ công với HEAD hiện tại trên `main` (sau commit `7efaf7b93473e77b3f18367ff877168637a7aab4`).
2. Kiểm tra trên iPhone: kéo panel bằng tay nắm; kéo nút zoom ở góc dưới phải; kiểm tra chữ/nút/list cùng scale; thu gọn thành nút ảo rồi kéo nút đi nơi khác và mở lại.
3. Nếu build lỗi hoặc thao tác còn giật, lấy log/kết quả thực tế rồi mới sửa tiếp; không sửa mò.
4. Chỉ sửa phạm vi Ara test panel. Không đụng chatbot/API, chat history, voice pipeline, Text Chat, Chibi Chat hoặc backup/workflow.

## Tiếp tục ở khung chat mới
Đọc checkpoint này, kiểm tra HEAD trên `main`, rồi đối chiếu đúng code panel. Chờ kết quả build/test thực tế trước khi tuyên bố hoàn tất. Không tạo branch.
