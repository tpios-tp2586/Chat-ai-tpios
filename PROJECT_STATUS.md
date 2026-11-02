# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trực tiếp trên `main`; tuyệt đối không tạo hoặc chuyển branch.
- Code mới nhất: `28119e4379c5fa8cf89b82d5fdde60bca82d2d00` — popup Ara bỏ chữ `Test`, chỉ hiện tên nhóm (`T. Chuyện`/`Y. Cầu`), thu gọn hàng tiêu đề và giữ danh sách một cột dọc.
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
- Popup không hiển thị chữ `Test`; màn hình chọn nhóm chỉ có hai ô `T. Chuyện` và `Y. Cầu` cùng nút đóng. Khi vào nhóm, tiêu đề chỉ hiện tên nhóm (ví dụ `Y. Cầu`), nút quay lại chỉ dùng icon mũi tên.
- Khi chưa chọn nhóm, popup tự co theo nội dung, chỉ đủ chứa hai ô `T. Chuyện` và `Y. Cầu` (40×40 pt) cùng nút đóng; không ép chiều rộng cố định. Khi vào nhóm, hàng tiêu đề gọn và không lặp chữ `Test`.
- Khi mở nhóm, các hành động xếp thành một cột dọc duy nhất; mỗi ô 40×40 pt, danh sách dài có thể cuộn.
- Chọn hành động chạy ngay clip tương ứng nhưng giữ popup và nhóm đang chọn mở để tiếp tục chọn/test; test mode chỉ bật nội bộ trong lúc chạy và tự kết thúc về Idle.
- Giữ nguyên toàn bộ 26 clip/action, callback, thời lượng animation, chuỗi Jump và log chẩn đoán; giữ nút sao chép log.
- Không sửa luồng avatar, chatbot/API, lịch sử chat, voice pipeline, Text Chat hoặc Chibi Chat.

## Việc tiếp theo
1. Người dùng chạy Codemagic thủ công trên `main`; chưa có xác nhận build thành công.
2. Trên iPhone, kiểm tra popup nhóm tự co vừa hai ô 40×40; trong từng nhóm, các hành động xếp một cột dọc; chọn liên tiếp nhiều hành động mà popup vẫn mở.
3. Kiểm tra LOG vẫn mở và sao chép được.
4. Kiểm tra Chat Voice vẫn dùng Theme chung và không còn nút/lớp phủ sáng-tối riêng.
5. Nếu có lỗi build hoặc UI chưa đúng, lấy log/ảnh thực tế rồi mới sửa tiếp. Không tự chạy build.

## Tiếp tục ở khung chat mới
Đọc checkpoint này, kiểm tra HEAD trên `main`, rồi kiểm tra popup TEST Ara tự co vừa hai nhóm, danh sách hành động một cột dọc, popup vẫn mở khi test liên tiếp; xác nhận chức năng sáng/tối riêng của Chat Voice đã được xóa. Không tạo branch và không tự chạy Codemagic/GitHub Actions.
