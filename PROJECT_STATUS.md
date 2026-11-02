# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trực tiếp trên `main`; tuyệt đối không tạo hoặc chuyển branch.
- Code mới nhất: `088c89f72bb32c03252a341ccfbcd13188a9ffcf` — thu gọn UI test Ara, bỏ hoàn toàn chức năng sáng/tối riêng của Chat Voice.
- Đây là checkpoint hiện tại; lịch sử thay đổi xem trong Git commits/diffs.

## Quy tắc bắt buộc
- Trước khi sửa code: kiểm tra HEAD và đọc code thực tế đúng phạm vi; không đoán.
- Ưu tiên thay đổi tối thiểu, không thêm dependency nếu không cần (Ponytail).
- Bảo vệ chatbot/API, chat history, voice pipeline, Text Chat và Chibi Chat. Không sửa các phần này khi làm Ara.
- Không tạo branch; không tự chạy/dispatch GitHub Actions hoặc Codemagic. Người dùng tự chạy build thủ công.
- Codemagic chỉ xuất IPA; không thêm ZIP artifact ngoài yêu cầu.
- Người dùng thao tác chủ yếu trên iPhone; hướng dẫn ngắn gọn, rõ ràng.

## Hướng hiện tại
- Tiếp tục Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Không quay lại phương án 8 ảnh biểu cảm thay cho avatar 3D.
- Ara đã load và phát animation trên iPhone ở các lần build trước; cần đánh giá bằng quan sát thực tế, không chỉ dựa vào log.
- Không thay đổi chatbot hoặc voice pipeline để xử lý animation/UI test.

## Ara — giao diện test
- Trên thanh công cụ Chat Voice, giữ nút LOG và thay nút sáng/tối bằng icon TEST cùng kích thước 42×42 pt như LOG.
- Xóa hoàn toàn chức năng sáng/tối riêng của Chat Voice: state `nightMode`, nút đổi nền và lớp phủ đen. Vẫn giữ Theme chung của ứng dụng qua `activeTheme`.
- Icon TEST mở popup SwiftUI tự thiết kế; không dùng native Menu hoặc sheet cho phần test.
- Popup có tiêu đề `Test`, nút bật/tắt test mode ngắn gọn `Bật/Tắt`, và hai ô nhóm 90×90 pt: `T. Chuyện` và `Y. Cầu`.
- Mỗi nhóm hiển thị các hành động thành ô 90×90 pt, chữ nhỏ; danh sách Yêu cầu có thể cuộn.
- Chọn hành động sẽ đóng popup và gọi logic test hiện có.
- Giữ nguyên toàn bộ 26 clip/action, callback, thời lượng animation, chuỗi Jump, test mode và log chẩn đoán; giữ nút sao chép log.
- Không sửa luồng avatar, chatbot/API, lịch sử chat, voice pipeline, Text Chat hoặc Chibi Chat.

## Việc tiếp theo
1. Người dùng chạy Codemagic thủ công trên `main`; chưa có xác nhận build thành công.
2. Trên iPhone, kiểm tra icon TEST cạnh LOG, popup nhóm 90×90, các ô hành động 90×90, nút bật/tắt và thao tác đóng popup.
3. Kiểm tra LOG vẫn mở và sao chép được.
4. Kiểm tra Chat Voice vẫn dùng Theme chung và không còn nút/lớp phủ sáng-tối riêng.
5. Nếu có lỗi build hoặc UI chưa đúng, lấy log/ảnh thực tế rồi mới sửa tiếp. Không tự chạy build.

## Tiếp tục ở khung chat mới
Đọc checkpoint này, kiểm tra HEAD trên `main`, rồi kiểm tra popup TEST Ara dạng ô 90×90 và xác nhận chức năng sáng/tối riêng của Chat Voice đã được xóa. Không tạo branch và không tự chạy Codemagic/GitHub Actions.
