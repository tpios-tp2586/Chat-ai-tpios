# PROJECT_STATUS.md — ChatAI

## Repo và nguyên tắc
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Làm trực tiếp trên `main`; không tạo hoặc chuyển sang branch khác.
- Kiểm tra code thực tế trước khi sửa; ưu tiên thay đổi tối thiểu, không thêm dependency không cần thiết.
- Bảo toàn Text Chat, Chibi Chat, API, lịch sử chat và pipeline giọng nói.
- Build phát hành qua Codemagic; đầu ra mong muốn là IPA, không thêm ZIP artifact.

## Trạng thái avatar Ara
- Chat Voice dùng `AraAvatarView` (RealityKit).
- Đã chuyển quy trình tạo model từ repo Ara-Avatar-Test sang ChatAI:
  - `.github/workflows/generate-ara-usdz.yml`
  - `scripts/verify-glb.mjs`
  - `scripts/split-glb-animations.mjs`
  - `scripts/compact-glb-primitives.mjs`
- Chạy thủ công qua GitHub Actions trên `main`; workflow tạo GLB, xác minh rig/animation, tách Idle/Wave/Talk, tối ưu, chuyển USDZ và kiểm tra animation.
- Workflow lưu artifact trung gian 14 ngày và phát hành 3 USDZ cùng SHA/report vào Release tag `ara-avatar-v1` của repo ChatAI.
- Workflow dùng `GITHUB_TOKEN` tự cấp với quyền `contents: write`; không cần PAT riêng.
- App tải từng clip theo nhu cầu, kiểm tra SHA-256 và lưu cache trong Application Support. **Lưu ý:** repo ChatAI Private nên URL Release không thể tải ẩn danh trực tiếp từ iPhone; cần xử lý cơ chế phân phối có xác thực trước khi coi tính năng tải model hoàn tất. Không nhúng token GitHub vào app và không đóng gói USDZ vào IPA.

## Việc cần kiểm tra tiếp
1. Chạy workflow `Generate Ara USDZ avatar assets` thủ công và xác nhận đủ ba USDZ được phát hành.
2. Giải quyết quyền tải model từ repo Private cho app iPhone mà không nhúng token.
3. Chạy Codemagic build IPA và sửa lỗi compile nếu có.
4. Cài trên iPhone: xác nhận tải Idle, chuyển Talk/Wave, cache hoạt động khi mở lại và khi offline.
5. Chỉ sau khi Ara chạy ổn mới dọn ảnh tham khảo trong `Reference/FaceExpressions` nếu không còn cần giữ.

## Đã loại bỏ
- Đã xóa `ChatAI/ChatAIHead3DView.swift`, phần triển khai SceneKit cũ có tham chiếu `Model-02.usdz`.
- Đã bỏ exclusion tương ứng khỏi `project.yml`.
- Không còn tích hợp Model-02 trong luồng Chat Voice.
