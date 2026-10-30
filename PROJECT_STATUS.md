# PROJECT_STATUS.md — ChatAI

## Repo và nguyên tắc
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Làm trực tiếp trên `main`; không tạo hoặc chuyển sang branch khác.
- Kiểm tra code thực tế trước khi sửa; ưu tiên thay đổi tối thiểu, không thêm dependency không cần thiết.
- Bảo toàn Text Chat, Chibi Chat, API, lịch sử chat và pipeline giọng nói.
- Build phát hành qua Codemagic; đầu ra mong muốn là IPA, không thêm ZIP artifact.

## Trạng thái hiện tại
- Chat Voice đã chuyển vùng avatar sang `AraAvatarView` dùng RealityKit.
- Ba mô hình được tải trực tiếp từ GitHub Release `ara-avatar-v1` của chính repo này:
  - `Ara-Idle.usdz`
  - `Ara-Talk.usdz`
  - `Ara-Wave.usdz`
- Tải từng clip theo nhu cầu; lưu trong Application Support để dùng lại offline.
- Kiểm tra SHA-256 trước khi lưu cache.
- Chat Voice điều khiển Talk khi AI nói, Wave khi phiên live bắt đầu, sau đó Idle.
- Log chẩn đoán và nút sao chép log hiện có được giữ lại; Ara ghi trạng thái tải và lỗi vào log.

## Việc cần kiểm tra tiếp
1. Chạy Codemagic build IPA và sửa lỗi compile nếu có.
2. Cài trên iPhone: xác nhận tải Idle, chuyển Talk/Wave, cache hoạt động khi mở lại và khi offline.
3. Kiểm tra khung hình/kích thước model trên thiết bị thật.
4. Chỉ sau khi Ara chạy ổn mới dọn các ảnh biểu cảm tham khảo trong `Reference/FaceExpressions` nếu không còn cần giữ làm tư liệu.

## Đã loại bỏ
- Đã xóa `ChatAI/ChatAIHead3DView.swift`, phần triển khai SceneKit cũ có tham chiếu `Model-02.usdz`.
- Đã bỏ exclusion tương ứng khỏi `project.yml`.
- Không còn tích hợp Model-02 trong luồng Chat Voice.
