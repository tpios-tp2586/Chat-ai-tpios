

## Quy tắc làm việc bắt buộc — do chủ repo đặt ra

**Mọi AI, trợ lý, cộng tác viên hoặc người thực hiện thay đổi trong repo phải tuân thủ các quy tắc dưới đây. Không được tự ý bỏ qua.**

1. **Không tự ý hành động ngoài yêu cầu.** Chỉ thực hiện đúng phạm vi công việc mà chủ repo đã yêu cầu hoặc phê duyệt rõ ràng.
2. **Không tạo nhánh mới.** Tuyệt đối không tự tạo branch, nhánh thử nghiệm hay nhánh phụ. Làm trực tiếp trên `main`, theo chỉ thị của chủ repo.
3. **Phải xin phép trước khi thay đổi hướng làm hoặc phạm vi.** Nếu định làm việc chưa được yêu cầu rõ, có rủi ro ảnh hưởng phần khác, hoặc cần lựa chọn giữa các phương án quan trọng, phải dừng và hỏi chủ repo trước.
4. **Không tự ý sửa/xóa/di chuyển file ngoài phạm vi.** Không tự ý đổi cấu trúc dự án, thay thư viện, thêm dependency, thay cấu hình build, workflow, quyền truy cập, secrets hoặc thiết lập repo nếu chưa được đồng ý.
5. **Bảo vệ tính năng đang hoạt động.** Với ChatAI, giữ nguyên chatbot, API, lịch sử chat và voice đang chạy ổn khi nhiệm vụ chỉ liên quan đến avatar 3D. Chỉ sửa các phần cần thiết cho yêu cầu hiện tại.
6. **Kiểm tra trước khi sửa.** Đọc code và log liên quan, xác định nguyên nhân và phạm vi tác động trước khi thay đổi. Không đoán rồi sửa hàng loạt.
7. **Ưu tiên thay đổi tối thiểu (Ponytail).** Không over-engineer, không tạo abstraction/dependency không cần thiết, không xây thêm thứ chưa được yêu cầu.
8. **Không tuyên bố đã kiểm tra hoặc hoàn thành nếu chưa xác minh.** Nêu rõ kiểm tra nào đã chạy, kết quả build/test thực tế, giới hạn còn lại và file/commit đã thay đổi. Không được bịa kết quả.
9. **Không tự ý merge, phát hành hoặc triển khai.** Những hành động này cần được chủ repo yêu cầu hoặc chấp thuận rõ ràng.
10. **Báo cáo sau mỗi lần sửa.** Tóm tắt mục tiêu, file thay đổi, lý do, kiểm tra đã thực hiện và vấn đề còn lại bằng ngôn ngữ dễ hiểu.

### Quy tắc ưu tiên

Nếu yêu cầu hiện tại chưa rõ, có mâu thuẫn, hoặc có nguy cơ làm hỏng tính năng đang chạy, **dừng lại và hỏi chủ repo; không tự quyết định thay chủ repo**. Các quy tắc này áp dụng cho mọi công việc tiếp theo trong repo và chỉ chủ repo mới có quyền thay đổi chúng.

