# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Branch duy nhất được dùng: `main`. Tuyệt đối không tự tạo/chuyển branch.
- HEAD đã kiểm tra: `e09b99bb0b74b3941023bd103b2da1584a3ccb7b` — `Record Ara resize state compile fix`.
- File này là checkpoint trạng thái hiện tại, không phải nhật ký. Lịch sử thay đổi nằm trong Git commits/diffs.

## Quy tắc bắt buộc
- Trước khi sửa code: kiểm tra HEAD/status và đọc code thực tế đúng phạm vi; không đoán.
- Chỉ sửa tối thiểu, không thêm dependency nếu không cần (Ponytail).
- Giữ nguyên chatbot/API, chat history, voice pipeline, Text Chat và Chibi Chat. Không sửa các phần này khi làm Ara.
- Không tạo branch. Không tự chạy/dispatch GitHub Actions hoặc Codemagic; user tự chạy thủ công.
- Codemagic: chỉ cần IPA, không tạo ZIP artifact ngoài yêu cầu.
- Không sửa backup file/workflow. Người dùng thao tác chủ yếu trên iPhone; báo kết quả ngắn gọn, rõ ràng.

## Hướng hiện tại
- Tiếp tục Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Không quay lại hướng 8 ảnh biểu cảm thay cho avatar 3D; hướng hiện tại là Ara 3D.
- Ara đã load và phát animation trên iPhone ở các lần build trước. Không được suy ra chất lượng chuyển động chỉ từ log; cần quan sát trực tiếp trên iPhone.
- Không thay đổi chatbot hoặc voice pipeline để làm animation/UI test.

## Trạng thái Ara test panel trên main
- Các thay đổi gần đây tập trung vào bảng Test Ara nổi trên màn hình Chat Voice.
- Kéo bảng bằng riêng thanh tiêu đề; đã chuyển sang transient gesture state để giảm giật.
- Nút resize và thu gọn được đặt bên trong thanh tiêu đề của panel; resize dùng thao tác kéo ngang, thu gọn về icon 60×60pt.
- State compile bị thiếu `isResizingTestPanel` đã được khai báo trong commit `f7c9a085729a362eb3ea11bf01287ee031c047b3`; commit mới nhất `e09b99bb0b74b3941023bd103b2da1584a3ccb7b` ghi nhận compile fix.
- **Chưa có xác nhận build Codemagic và kiểm thử iPhone cho HEAD hiện tại.** Người dùng trước đó phản ánh thao tác kéo còn giật và UI chưa đúng mong muốn. Không kết luận panel đã hoàn thiện.
- Chưa được tự ý tiếp tục sửa nhiều vòng. Trước tiên cần chờ kết quả build/test hiện tại hoặc kiểm tra code thực tế để xác định đúng điểm lỗi.

## Việc tiếp theo
1. Người dùng chạy Codemagic thủ công với HEAD hiện tại và kiểm tra trên iPhone.
2. Ghi nhận riêng từng vấn đề còn lại: độ mượt khi kéo, vùng kéo chỉ ở header, resize, thu gọn/mở lại, vị trí/kích thước panel và khả năng panel che Ara.
3. Nếu còn lỗi, kiểm tra đúng Swift view/state/gesture đang chạy trên `main`, sửa tối thiểu một lượt có mục tiêu; không tạo branch và không đụng chatbot/voice pipeline.
4. Chỉ cập nhật trạng thái hoàn tất sau khi có kết quả build và quan sát thực tế trên iPhone.

## Cách tiếp tục ở khung chat mới
Đọc file này trước, sau đó kiểm tra HEAD mới nhất trên `main`. Không cần đọc lại toàn bộ lịch sử hội thoại; chỉ mở các file code liên quan nếu cần sửa. Nếu HEAD khác hash ghi ở trên, đối chiếu commit mới trước khi làm tiếp.
