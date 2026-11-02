# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trực tiếp trên `main`; tuyệt đối không tạo hoặc chuyển branch.
- Code giao diện Ara gần nhất: `61f55bc9636bb879fc5a9708f154dc7f969a4367` — popup TEST bỏ chữ `Test`, chỉ hiện tên nhóm (`T. Chuyện`/`Y. Cầu`), thu gọn hàng tiêu đề và giữ danh sách một cột dọc.
- Checkpoint trước lần cập nhật này: `db9591b1678918b80ba082dc78f0cb84f10831f1`.
- Lịch sử thay đổi xem trong Git commits/diffs.

## Quy tắc bắt buộc
- Trước khi sửa code: kiểm tra HEAD và đọc code thực tế đúng phạm vi; không đoán.
- Ưu tiên thay đổi tối thiểu, không thêm dependency nếu không cần (Ponytail).
- Bảo vệ chatbot/API, chat history, voice pipeline, Text Chat và Chibi Chat. Không sửa các phần này khi làm Ara.
- Không tạo branch; không tự chạy/dispatch GitHub Actions hoặc Codemagic. Người dùng tự chạy build thủ công.
- Codemagic chỉ xuất IPA; không thêm ZIP artifact ngoài yêu cầu.
- Người dùng thao tác chủ yếu trên iPhone; hướng dẫn ngắn gọn, rõ ràng.
- Không sửa đi sửa lại từng chi tiết nhỏ. Phải hiểu và chốt yêu cầu, kiểm tra toàn bộ code liên quan, gom thay đổi thành một lần hợp lý, rà diff trước khi commit.

## Hướng hiện tại
- Tiếp tục Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Không quay lại phương án 8 ảnh biểu cảm thay cho avatar 3D.
- Ara đã load và phát animation trên iPhone ở các lần build trước; cần đánh giá bằng quan sát thực tế, không chỉ dựa vào log.
- Không thay đổi chatbot hoặc voice pipeline để xử lý animation/UI test.

## Ara — giao diện TEST (tạm chốt)
- Trên thanh công cụ Chat Voice, giữ nút LOG và nút TEST cùng kích thước 42×42 pt.
- Chức năng sáng/tối riêng của Chat Voice đã được xóa: state `nightMode`, nút đổi nền và lớp phủ đen. Vẫn giữ Theme chung của ứng dụng qua `activeTheme`.
- Icon TEST mở popup SwiftUI tự thiết kế; không dùng native Menu hoặc sheet cho phần test.
- Popup không hiển thị chữ `Test`; màn hình chọn nhóm chỉ có hai ô `T. Chuyện` và `Y. Cầu` cùng nút đóng. Khi vào nhóm, tiêu đề chỉ hiện tên nhóm, nút quay lại chỉ dùng icon mũi tên.
- Popup tự co theo nội dung; hàng tiêu đề gọn. Khi mở nhóm, các hành động xếp thành một cột dọc; mỗi ô 40×40 pt, danh sách dài có thể cuộn.
- Chọn hành động chạy clip tương ứng nhưng giữ popup và nhóm đang chọn mở để tiếp tục test; test mode chỉ bật nội bộ trong lúc chạy và tự kết thúc về Idle.
- Giữ nguyên 26 clip/action, callback, thời lượng animation, chuỗi Jump và log chẩn đoán; giữ nút sao chép log.
- Người dùng đánh giá phần TEST hiện tại là tạm ổn. Không tiếp tục chỉnh sửa giao diện/chức năng TEST nếu chưa có yêu cầu mới.
- **Đã loại bỏ hoàn toàn khỏi tool** chức năng kéo di chuyển, zoom/thu phóng và thu gọn/resize khung test vì hoạt động không ổn. Không khôi phục, không tối ưu lại, không đưa các chức năng này thành đầu việc tiếp theo.

## Trạng thái và việc tiếp theo
- Phần TEST tạm chốt; không tự ý chỉnh thêm.
- Chưa xác định đầu việc phát triển tiếp theo. Không suy diễn từ ghi chú cũ hoặc tự đề xuất lại các chức năng kéo/zoom đã bị loại bỏ. Chờ người dùng xác nhận mục tiêu tiếp theo.
- Trạng thái build Codemagic mới nhất chưa được xác nhận trong checkpoint này; không tự chạy build.
- Nếu người dùng báo lỗi build/UI, yêu cầu log hoặc ảnh thực tế phù hợp rồi mới điều tra và sửa.

## Tiếp tục ở khung chat mới
Đọc checkpoint này và kiểm tra HEAD trên `main` trước khi làm việc. Phần TEST Ara đang tạm chốt. Tuyệt đối không khôi phục chức năng kéo di chuyển, zoom/thu phóng hoặc thu gọn/resize khung test đã bị loại bỏ. Chưa có đầu việc tiếp theo được xác nhận; hỏi người dùng trước khi bắt đầu. Không tạo branch và không tự chạy Codemagic/GitHub Actions.
