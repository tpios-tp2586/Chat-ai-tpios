# PROJECT_STATUS.md — ChatAI

## Mục đích
Tài liệu bàn giao duy nhất để mở chat mới và tiếp tục đúng công việc. Luôn đối chiếu code và log thực tế trong repo trước khi sửa.

## Repo và quy tắc
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trên `main`; tuyệt đối không tạo hoặc chuyển sang branch khác.
- Kiểm tra code liên quan trước khi sửa; ưu tiên diff nhỏ, không thêm dependency nếu không cần.
- Giữ ổn định chatbot, API, lịch sử chat, voice pipeline và các màn hình đang hoạt động.
- Build bằng Codemagic; đầu ra mong muốn là IPA.

## Trạng thái hiện tại
- Chat chữ đang hoạt động; không chỉnh sửa khi làm avatar.
- Chibi chat đang hoạt động; không chỉnh sửa.
- Chat Voice/Companion là khu vực thử nghiệm hiện tại.
- Đã dừng hướng avatar 3D. Hướng hiện tại là dùng 8 ảnh biểu cảm PNG trong `Reference/FaceExpressions`.
- Ảnh gồm: angry, happy, neutral, sleepy, speaking, surprised, thinking, wink.
- Mục tiêu trước mắt: đóng gói đúng 8 ảnh vào app, hiển thị theo trạng thái cảm xúc/giọng nói và giữ nút xem/sao chép log chẩn đoán.
- Không thay đổi Gemini Live, micro, xử lý âm thanh hoặc luồng chat chính nếu không liên quan trực tiếp.

## Việc cần xác minh sau thay đổi
- XcodeGen đưa thư mục FaceExpressions vào resource bundle.
- Màn hình Chat Voice hiển thị ảnh thay cho đầu robot vẽ bằng SwiftUI.
- Log xác nhận đường dẫn và số ảnh tìm thấy trong bundle.
- Codemagic build thành công và chỉ xuất IPA.
