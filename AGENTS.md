# AGENTS.md — Quy tắc bắt buộc cho AI và người đóng góp

Các hướng dẫn này áp dụng cho mọi AI agent, trợ lý lập trình và người đóng góp làm việc trong repository này. Đọc và tuân thủ trước khi kiểm tra hoặc chỉnh sửa mã nguồn.

## 1. Quyền quyết định thuộc về chủ repo
- Chỉ thực hiện đúng phạm vi công việc mà chủ repo đã yêu cầu hoặc phê duyệt rõ ràng.
- Không tự ý mở rộng nhiệm vụ, đổi hướng triển khai, thêm tính năng, sửa lỗi không liên quan hoặc thực hiện việc “tiện thể”.
- Nếu yêu cầu chưa rõ, có rủi ro, hoặc cần thay đổi ngoài phạm vi đã duyệt: dừng lại và hỏi trước. Không tự suy đoán sự đồng ý.
- Không được tự sửa, xóa, ghi đè hoặc vô hiệu hóa các quy tắc này. Chỉ chủ repo mới có quyền thay đổi chúng.

## 2. Làm việc trực tiếp trên main
- Theo chỉ thị của chủ repo, chỉ làm việc trực tiếp trên nhánh `main`.
- **Không tạo nhánh mới**, không tự chuyển sang nhánh khác, không tạo pull request để thay thế quy trình làm việc trên `main`.
- Không merge, phát hành release, triển khai hoặc thay đổi cài đặt repository nếu chưa được chủ repo cho phép rõ ràng.
- Trước khi ghi thay đổi, xác nhận đúng repository, đúng tệp và đúng nhánh đích.

## 3. Không đụng đến phần không liên quan
- Chỉ sửa những tệp tối thiểu cần thiết để hoàn thành yêu cầu.
- Không tự ý xóa, di chuyển, đổi tên hoặc định dạng lại các tệp không liên quan.
- Không thay đổi cấu trúc dự án, dependency, cấu hình build, workflow CI/CD, quyền truy cập, secrets hoặc thiết lập repository nếu chưa được phê duyệt.
- Nếu nhiệm vụ chỉ liên quan đến avatar 3D, phải giữ nguyên chatbot, API, lịch sử hội thoại và hệ thống giọng nói đang hoạt động.

## 4. Kiểm tra trước khi sửa
- Đọc mã nguồn, cấu hình và log thực tế liên quan trước khi đề xuất hoặc thực hiện thay đổi.
- Xác định rõ nguyên nhân và phạm vi ảnh hưởng; ưu tiên bản sửa nhỏ nhất có thể.
- Áp dụng nguyên tắc Ponytail: tránh over-engineering, abstraction không cần thiết, dependency mới và thay đổi ngoài yêu cầu.
- Không giả định build hoặc test đã thành công. Chỉ báo cáo những gì đã thực sự chạy và xác minh.

## 5. Xác minh và báo cáo
Sau khi được phép sửa, báo cáo rõ:
- Những tệp đã thay đổi và lý do.
- Các lệnh kiểm tra/build/test đã thực sự chạy cùng kết quả.
- Những phần chưa kiểm tra được, lỗi còn tồn tại và rủi ro đã biết.
- Không tuyên bố hoàn tất nếu chưa có bằng chứng xác minh phù hợp.

## 6. Khi công cụ yêu cầu xác nhận
- Nếu công cụ hoặc nền tảng hỗ trợ phê duyệt trước khi ghi tệp, thay đổi quyền hoặc thực hiện hành động có tác động lớn, hãy dùng bước phê duyệt đó.
- Không tìm cách lách giới hạn quyền, xác nhận của người dùng hoặc chính sách bảo vệ.
- Tài liệu hướng dẫn này không thay thế quyền kiểm soát kỹ thuật của GitHub hay cài đặt xác nhận của từng công cụ. Nếu một công cụ không hỗ trợ hoặc không thể bảo đảm tuân thủ, phải nói rõ giới hạn đó.

## Nguyên tắc ưu tiên
**Không chắc thì hỏi. Chưa được duyệt thì không làm. Chỉ làm đúng phạm vi đã duyệt. Không tạo nhánh; làm trên main theo chỉ thị của chủ repo.**
