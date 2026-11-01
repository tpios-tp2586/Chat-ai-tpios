# ChatAI — Project Status

## Project
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Branch chính: `main`. Không tự tạo/chuyển branch.
- Build iOS: Codemagic; artifact mong muốn: IPA, không thêm ZIP artifact.
- PROJECT_STATUS.md là snapshot trạng thái hiện tại, không phải nhật ký phát triển. Git commit/diff lưu lịch sử thay đổi.

## Quy tắc làm việc
- Trước khi sửa: kiểm tra trạng thái repo và đọc code thực tế của đúng phạm vi; không đoán.
- Ưu tiên thay đổi tối thiểu; không thêm dependency nếu không cần.
- Bảo vệ chatbot/API, chat history, voice transport/pipeline, Text Chat và Chibi Chat. Không sửa Text Chat/Chibi Chat khi làm Ara.
- Assistant không tự chạy/dispatch GitHub Actions hoặc Codemagic. User tự chạy thủ công và gửi kết quả để kiểm tra.
- Không sửa file backup/backup workflow; user tự quản lý backup.
- User thao tác chủ yếu trên iPhone; báo kết quả ngắn gọn, rõ ràng.
- Session Checkpoint: đọc status một lần ở đầu phiên/khôi phục; trong phiên chỉ đọc file liên quan; checkpoint sau mỗi công đoạn quan trọng hoặc trước khi chuyển phiên. Khi cập nhật status, thay thế nội dung cũ bằng snapshot mới, không nối nhật ký.

## Hướng chính thức — Ara 3D
- User xác nhận tiếp tục phát triển Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Ara đã tải và phát animation trên iPhone trong các lần thử, nhưng chưa được xác nhận ổn định/hoàn thiện.
- Phong cách mục tiêu: tự nhiên, nhẹ nhàng, nữ tính; tránh động tác phóng đại, lặp gật đầu hoặc nhìn quanh.
- Ưu tiên nghiên cứu hiện tại: biểu cảm khuôn mặt và ngữ cảnh lời nói trước; cử chỉ cơ thể phù hợp nội dung tiếp theo; lip-sync/viseme để sau.
- Không thay chatbot hoặc voice pipeline để phát triển animation. Không lấy `aiSpeaking` đơn thuần làm căn cứ duy nhất chọn cảm xúc/gesture.

## Pipeline Ara hiện tại
- Workflow tạo asset: `.github/workflows/generate-ara-usdz.yml` trên `main`, chạy thủ công khi user yêu cầu.
- Upstream: https://github.com/olatunde85/3d-gen, pin commit `e26cdef1464a0babf23bb0235b5f05930301ee25`.
- Nguồn upstream có 70+ animation clips; rig GLB đã kiểm tra có 69 joints và 34 morph targets. Pipeline ChatAI tạo timeline hội thoại 8 clip/26 giây, đóng gói thành một USDZ animation để app cắt clip bằng RealityKit.
- RealityKit có thể nhập timeline USDZ thành một global scene animation; không giả định tên clip gốc được giữ nguyên. App chủ động cắt các đoạn timeline. Các clip full-rig không được mặc định layer đồng thời.
- Workflow/script chính: `scripts/split-glb-animations.mjs`, `scripts/compact-glb-primitives.mjs`, `scripts/apply-ara-talk-explain.mjs`, `scripts/inspect-ara-animation.mjs`, `scripts/ara-research-data.py`, `scripts/inspect-ara-usdz-animation.py`, `scripts/apply-ara-hip-sway.py`.
- GitHub workflow `.github/workflows/generate-ara-usdz.yml` convert GLB thành `Ara-Avatar.usdz` chưa có Hips sway; artifact kèm marker `hips_sway_baked=false`, timeline và diagnostics. Hips sway không còn được bake trong GitHub Actions.
- Codemagic `ios-unsigned` tải artifact mới nhất từ `main`, tạo Python virtualenv tạm, cài `usd-core==26.5` và kiểm tra `pxr.Usd`, `pxr.UsdSkel`, `pxr.UsdUtils`. Trước Xcode build, Codemagic chạy `scripts/apply-ara-hip-sway.py` để bake Hips Y ±3°/0.8 Hz/30 FPS vào `ChatAI/Resources/Ara-Avatar.usdz`, sau đó kiểm tra USDZ và animation. OpenUSD chỉ nằm trong môi trường build tạm, không thêm dependency vào app.
- `AraAvatarView.swift` đã bỏ hoàn toàn Hips sway additive ±5° lúc runtime; sway chỉ còn trong USDZ đã bake.
- Codemagic Xcode 16.4 runner công bố Python 3.12.7; PyPI có wheel macOS universal2 cho `usd-core==26.5`/CPython 3.12. Chưa chạy thực tế nên khả năng cài/import và xử lý USDZ trên Codemagic vẫn chờ user xác minh.
- Workflow có kiểm tra GLB và USDZ, joint animation, morphs, texture references và research bundle nén. Không chạy lại workflow chỉ để thử từng giả thuyết; ưu tiên gom kiểm tra cần thiết vào một lần chạy.

## Trạng thái kỹ thuật đã xác minh
- TalkExplain đã được trigger/phát và quay về Talk trong runtime; trước đây cử chỉ tay nhìn thấy chưa rõ.
- Diagnostic GLB trước đây cho thấy TalkExplain khác Talk rõ ở RightArm/RightForeArm/RightHand; post-conversion USDZ cũng có báo cáo joint samples. Không suy luận rằng conversion hoặc playback đúng chỉ từ việc workflow thành công.
- Có lần converter cảnh báo skeletal animation chứa node animation và unresolved texture references; workflow đã được bổ sung kiểm tra texture và kiểm tra số liệu sau conversion.
- AraAvatarView đã được cập nhật để dừng playback controller trước khi phát clip mới; vẫn cần xác minh runtime trên iPhone.
- Các kết quả run cũ và lịch sử thử nghiệm chi tiết nằm trong GitHub Actions artifacts/commits, không chép lại vào status này.

## Việc tiếp theo
1. User chạy thủ công GitHub workflow trên `main` để tạo artifact USDZ chưa bake sway.
2. Sau khi artifact mới hoàn tất, user chạy Codemagic; xác minh OpenUSD cài/import thành công, Hips sway được bake và USDZ qua kiểm tra trước khi build IPA.
3. Cài/test trên iPhone thật, đối chiếu log và quan sát chuyển động; chỉ kết luận Ara ổn định khi có xác minh thực tế.

## Build và xác minh
- Codemagic workflow chính: `ios-unsigned`; assistant không dispatch Codemagic trực tiếp.
- Build simulator chỉ xác nhận compile/package, không thay thế kiểm thử trên iPhone thật.
- Không build IPA từ asset mới trước khi review kết quả USDZ post-conversion.
