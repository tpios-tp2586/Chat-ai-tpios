# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trực tiếp trên `main`; tuyệt đối không tạo hoặc chuyển branch.
- Code mới nhất: `7cdba2f309fa540a430ca0439790cda343c67255` — thay giao diện test Ara bằng sheet hành động gọn.
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
- Nút test trên header mở một sheet native gọn ở mức medium; không còn giao diện nổi phủ màn hình.
- Sheet dùng segmented picker để chuyển giữa hai nhóm: `Khi trò chuyện` và `Theo yêu cầu`.
- Danh sách hành động cuộn bên trong sheet; chọn hành động vẫn gọi các hàm test hiện có `testAraGesture` và `testJumpSequence`.
- Giữ nguyên danh sách clip, callback, thời lượng animation, chuỗi nhảy và log chẩn đoán.
- Khi mở chế độ test, phiên Live đang chạy được dừng như logic hiện tại; khi đóng sheet, test mode kết thúc và Ara trở về Idle.
- Không có thao tác kéo vị trí, zoom/resize, thu gọn thành nút nổi hoặc lưu tọa độ/kích thước. Các giá trị UserDefaults cũ của giao diện trước được dọn khi màn hình Chat Voice xuất hiện.
- Chỉ thay đổi phần UI test Ara; không sửa luồng avatar, chatbot/API hay voice pipeline.

## Việc tiếp theo
1. Người dùng chạy Codemagic thủ công trên `main` với commit mới nhất.
2. Trên iPhone, kiểm tra nút test mở sheet, chuyển được hai nhóm, cuộn danh sách và chạy thử một số animation, gồm cả Jump sequence.
3. Xác nhận đóng sheet đưa Ara về Idle và phiên chat thoại có thể khởi động lại bình thường.
4. Nếu có lỗi build hoặc hành động không chạy đúng, lấy log/kết quả thực tế rồi mới sửa tiếp. Không tự chạy build.

## Tiếp tục ở khung chat mới
Đọc checkpoint này, kiểm tra HEAD trên `main`, rồi đối chiếu đúng giao diện test hành động Ara. Không tạo branch và không tự chạy Codemagic/GitHub Actions.
