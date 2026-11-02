# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trực tiếp trên `main`; tuyệt đối không tạo hoặc chuyển branch.
- Code mới nhất: `0b01468016ee0f7cf2d9889c6471f42fbebbfd28` — khôi phục đầy đủ định dạng mã nguồn và thay sheet test Ara bằng native Menu nhỏ gọn.
- Đây là checkpoint hiện tại; lịch sử thay đổi xem trong Git commits/diffs.

## Quy tắc bắt buộc
- Trước khi sửa code: kiểm tra HEAD và đọc code thực tế đúng phạm vi; không đoán.
- Ưu tiên thay đổi tối thiểu, không thêm dependency nếu không cần (Ponytail).
- Bảo vệ chatbot/API, chat history, voice pipeline, Text Chat và Chibi Chat. Không sửa các phần này khi làm Ara.
- Không tạo branch; không tự chạy/dispatch GitHub Actions hoặc Codemagic. Người dùng tự chạy build thủ công.
- Codemagic chỉ xuất IPA; không thêm ZIP artifact ngoài yêu cầu.
- Không sửa backup file/workflow. Người dùng thao tác chủ yếu trên iPhone; hướng dẫn ngắn gọn, rõ ràng.

## Hướng hiện tại
- Tiếp tục Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Không quay lại phương án 8 ảnh biểu cảm thay cho avatar 3D.
- Ara đã load và phát animation trên iPhone ở các lần build trước; cần đánh giá bằng quan sát thực tế, không chỉ dựa vào log.
- Không thay đổi chatbot hoặc voice pipeline để xử lý animation/UI test.

## Ara — giao diện test hành động
- Bỏ sheet medium vì chiếm diện tích màn hình và che Ara.
- Chỉ còn một nút Test Ara hình tròn 60×60 pt, chữ `TEST` nhỏ, đặt gần góc trên bên phải màn hình Chat Voice.
- Chạm nút mở native SwiftUI `Menu` ngay tại nút; không có panel, sheet, kéo, zoom, resize hoặc lưu vị trí/kích thước.
- Menu có hai nhóm lồng nhau: `Khi trò chuyện` và `Theo yêu cầu`; giữ nguyên toàn bộ danh sách clip/action hiện có.
- Chọn action gọi logic test sẵn có `testAraGesture` hoặc `testJumpSequence`; nếu test mode chưa bật thì tự bật trước khi chạy.
- Có mục bật/tắt test mode riêng; tắt test mode sẽ hủy task và đưa Ara về Idle.
- Giữ nguyên callback, thời lượng animation, chuỗi Jump và log chẩn đoán; nút sao chép log vẫn được giữ.
- Chỉ thay đổi UI test Ara; không sửa luồng avatar, chatbot/API hay voice pipeline.

## Việc tiếp theo
1. Người dùng chạy Codemagic thủ công trên `main` với commit mới nhất.
2. Trên iPhone, kiểm tra nút TEST 60×60 ở góc trên bên phải; chạm để mở hai nhóm menu và chọn thử các action, gồm cả Jump sequence.
3. Kiểm tra bật/tắt test mode, Ara trở về Idle khi tắt, và phiên chat thoại có thể khởi động lại bình thường.
4. Nếu có lỗi build hoặc hành động không chạy đúng, lấy log/kết quả thực tế rồi mới sửa tiếp. Không tự chạy build.

## Tiếp tục ở khung chat mới
Đọc checkpoint này, kiểm tra HEAD trên `main`, rồi đối chiếu giao diện test Ara dạng nút TEST 60×60 với native Menu. Không tạo branch và không tự chạy Codemagic/GitHub Actions.
