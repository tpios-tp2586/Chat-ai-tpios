# PROJECT_STATUS.md — ChatAI

## Repo và nguyên tắc làm việc
- Repo chính: https://github.com/tpios-tp2586/Chat-ai-tpios
- Làm trực tiếp trên `main`; tuyệt đối không tự tạo/chuyển branch.
- Trước khi sửa: đọc trạng thái repo và code thực tế của đúng luồng liên quan; không đoán.
- Ưu tiên thay đổi tối thiểu, không thêm dependency không cần thiết.
- Bảo toàn Text Chat, Chibi Chat, chatbot/API, lịch sử chat và pipeline giọng nói. Không sửa Text Chat hoặc Chibi Chat khi làm Ara.
- Không chạy GitHub Actions nếu user chưa yêu cầu hoặc không thực sự cần. Không sửa file backup/backup workflow; user tự quản lý backup.
- Build iOS qua Codemagic; artifact mong muốn chỉ là IPA, không thêm ZIP build artifact.
- User chủ yếu thao tác trên iPhone; báo kết quả trực tiếp, tránh yêu cầu user lặp lại bối cảnh khi chuyển khung chat.

## Ara — mục tiêu và trạng thái hiện tại
- Ara là avatar 3D trong màn hình Chat Voice, dùng RealityKit.
- Âm thanh hội thoại hiện phát đúng. User đánh giá Ara đã chạy được nhưng CHƯA ổn định; không được gọi là đã ổn định.
- Hướng tạo hình/chuyển động đã chốt: tự nhiên, nhẹ nhàng, nữ tính; tránh động tác phóng đại hoặc lặp gật đầu/nhìn quanh.
- Mục tiêu đang làm: nghiên cứu và phát triển cử chỉ cơ thể phối hợp nội dung lời nói; phân biệt nghe, suy nghĩ, nói, chào và phản hồi. Trọng tâm là đầu, mắt, vai, thân trên, tay và nhịp điệu cử chỉ; không lấy việc nhìn rõ miệng làm tiêu chí duy nhất.
- Không thay chatbot/voice pipeline để làm cử chỉ. Chưa có yêu cầu sửa code ở giai đoạn nghiên cứu này.

## Lịch sử nguồn Ara và quy trình test — phải đọc trước khi tiếp tục
### 1. Repo test độc lập
- Repo: https://github.com/tpios-tp2586/Ara-Avatar-Test (private, default branch `main`).
- Đây là nơi thử nghiệm trước khi đưa Ara vào ChatAI; không phải repo ChatAI.
- Nguồn mở upstream được checkout trong workflow: https://github.com/olatunde85/3d-gen (`Ara 3D Gen`).
- Workflow test: `.github/workflows/build-avatar.yml`, chạy thủ công (`workflow_dispatch`), gồm:
  1. Checkout Ara 3D Gen, cài Node dependencies, chạy `npm run setup-assets`.
  2. Export preset `Athletic woman`, detail `high`, định dạng GLB.
  3. `scripts/verify-glb.mjs` kiểm tra GLB, skin, joints và animation.
  4. Upload artifact `ara-avatar-glb`.
  5. Checkout `robotson/usdz-forge`, setup OpenUSD converter.
  6. `scripts/split-glb-animations.mjs` tách riêng Idle/Wave/Talk; chuyển từng clip sang USDZ; inspect và probe xác nhận USDZ có animation.
  7. Upload artifact `ara-avatar-usdz`; workflow cũ còn build app thử nghiệm iOS Simulator và upload `ara-avatar-ios-simulator`.
- App thử nghiệm: `ios-test/Sources/AraAvatarTestApp.swift`, project config `ios-test/project.yml`; nạp USDZ từ app bundle, có picker Idle/Wave/Talk. Build simulator thành công chỉ chứng minh compile/package; không chứng minh chuyển động đẹp hoặc chạy đúng trên iPhone thật.
- Workflow `.github/workflows/build-ios-test.yml` là workflow build-only, tải USDZ artifact đã có rồi build app simulator; không tạo lại model/USDZ.
- Các lần chạy đã kiểm tra:
  - Run 40979770161 (`Ara avatar sample`): generate GLB và convert 3 USDZ đều SUCCESS.
  - Run 41003110577: generate và convert USDZ SUCCESS, nhưng job build-ios-test FAIL do `Scene is ambiguous for type lookup` trong `AraAvatarTestApp.swift`.
  - Run 41004609769 (`Ara iOS test build`): build-only dùng USDZ có sẵn; generate project, build simulator, package và upload artifact đều SUCCESS.
  - Run 40978386751 là lần generate GLB ban đầu SUCCESS.
- Không chạy lại các workflow test trừ khi user yêu cầu hoặc cần xác minh một thay đổi cụ thể.

### 2. Nguồn mở upstream — năng lực thực tế
- Repo: https://github.com/olatunde85/3d-gen
- `docs/animations.md` công bố 70 animation clips. Log GLB từ lần test 40979770161 xác nhận đúng 70 animations, 1 skin và 69 joints.
- 70 clips gồm Idle/Crouch idle; locomotion (Walk, Slouch walk, Run, Walk backwards, Strafe); Jump/Fall/Punch/Hit/Reactions; Emotes (Wave, Cheer, Laugh, Talk, Cry); Sit/Lie/Sleep; Turns; shooter; vehicle animations.
- Nguồn có code clip để mở rộng/chỉnh sửa: `src/core/anim/clips/`, gồm `basic.ts`, `actions.ts`, `emotes.ts`, `faces.ts`, `speech.ts`, `index.ts` và các bộ clip khác.
- `Talk` upstream KHÔNG phải cử chỉ tay giải thích: nó dựa trên Idle, thêm chuyển động nhẹ ở cổ/đầu theo stress và brow; phần speech face phát viseme giả lập cho preview. Tài liệu upstream nói lip-sync lời thoại thật phải được điều khiển từ audio/viseme tool riêng.
- `Wave` là cử chỉ chào; `Cheer` khá mạnh/phóng đại; `Laugh` là cử chỉ cười rõ. Trong 70 tên clip không có clip chuyên biệt kiểu Explain/Explain-with-hands hoặc Listening conversational gesture.
- Tài liệu upstream mô tả 34 blend shapes: 20 biểu cảm + 14 speech visemes. Đây là khả năng của nguồn GLB; không đồng nghĩa app hiện tại đang điều khiển viseme theo audio thật.
- License cần giữ đúng: source code Ara 3D Gen MIT; MakeHuman character assets CC0 1.0; motion capture CMU có điều khoản riêng: được dùng kể cả sản phẩm thương mại nhưng không được bán lại riêng dữ liệu motion capture đã chuyển đổi; giữ acknowledgement theo tài liệu nguồn.

### 3. Vì sao app hiện chỉ có Idle/Wave/Talk
- Log run 40979770161 của repo test ghi GLB: `Animations: 70`, `Skins: 1`, `Joints: 69`.
- Script `scripts/split-glb-animations.mjs` hiện chỉ tìm đúng ba tên `Idle`, `Wave`, `Talk`, rồi ghi ra ba GLB riêng. Nó không export 67 animation còn lại.
- Workflow test và workflow ChatAI đều chuyển ba GLB riêng đó thành ba USDZ; mỗi USDZ được probe có một skeletal animation.
- Vì vậy không phải nguồn Ara chỉ có ba chuyển động; pipeline hiện tại chủ động chỉ lấy ba trong tổng số 70.
- `AraAvatarView.swift` hiện định nghĩa ba clip `Ara-Idle`, `Ara-Wave`, `Ara-Talk`. Loader cache ba Entity riêng và khi đổi clip sẽ chuyển sang Entity tương ứng; mỗi model chạy `availableAnimations.first.repeat()`. Đây là đổi model/clip, không phải hệ thống nhiều lớp cử chỉ đồng thời trên một nhân vật.
- `CompanionChatView.swift` hiện chỉ đổi sang Talk khi `liveManager.aiSpeaking == true`, trở lại Idle khi ngừng nói; trạng thái live gọi Wave trong 3 giây. Nội dung câu nói chưa điều khiển cử chỉ.
- View hiện quan sát `liveManager.lines.count`; nếu text của một line được nối thêm mà số dòng không đổi thì thay đổi từng phần có thể không kích hoạt observer hiện tại. Cần xem lại cơ chế cập nhật transcript trước khi dùng nội dung câu nói để chọn gesture.

## Quy trình USDZ trong ChatAI — đã chuyển từ repo test
- Workflow chính: `.github/workflows/generate-ara-usdz.yml`, chạy thủ công trên `main`.
- Scripts: `scripts/verify-glb.mjs`, `scripts/split-glb-animations.mjs`, `scripts/compact-glb-primitives.mjs`.
- Workflow checkout `olatunde85/3d-gen`, tạo GLB, verify rig/animations, upload GLB artifact; sau đó checkout `robotson/usdz-forge`, split/compact Idle/Wave/Talk, convert USDZ, inspect/probe, upload artifact và publish Release.
- Lần chạy ChatAI đã xác minh: run 41041470989 (`Generate Ara USDZ avatar assets`, 2026-10-30) — cả job `generate` và `convert` SUCCESS.
- Run này xác nhận GLB được tạo và verify; tạo artifact `ara-avatar-glb`; tạo ba USDZ và artifact `ara-avatar-usdz`; publish các file `Ara-Idle.usdz`, `Ara-Wave.usdz`, `Ara-Talk.usdz`, `SHA256SUMS.txt`, `usdz-report.txt` vào Release tag `ara-avatar-v1`.
- Release: https://github.com/tpios-tp2586/Chat-ai-tpios/releases/tag/ara-avatar-v1
- Log converter có warning OpenUSD về một số đường dẫn texture `texgen_*.png/jpg` không resolve trong bước localization, nhưng inspect/probe vẫn thấy mỗi USDZ có 10 meshes, 1 skeleton, 1 skelAnimation và workflow kết thúc SUCCESS. Không được kết luận warning này vô hại với hiển thị texture nếu chưa kiểm tra trực quan trên thiết bị.
- `codemagic.yaml` lấy artifact `ara-avatar-usdz` mới nhất từ Actions của repo ChatAI bằng `GITHUB_TOKEN` trong nhóm `ara_secrets`, giải nén vào `ChatAI/Resources`, kiểm tra đủ ba file rồi XcodeGen/build. XcodeGen thêm Resources vào app bundle. App nạp bằng `Bundle.main`; không tải Release/URLSession lúc chạy.
- Workflow tạo USDZ của ChatAI đã thành công; điều này không tự chứng minh IPA hiện tại chứa đúng tài nguyên hoặc mọi animation hiển thị hoàn hảo trên iPhone.

## Hướng nghiên cứu cử chỉ tiếp theo — phong cách tự nhiên, nhẹ nhàng
1. Không đưa cả 70 clip vào app. Chọn rất ít clip phù hợp sau khi xem/đánh giá trực quan.
2. Tận dụng Idle làm chuyển động nền; Wave chỉ chạy một lần lúc chào; Talk giữ vai trò nền khi phát âm thanh nhưng hiện chỉ có nod/tilt đầu-cổ, không có gesture tay giải thích.
3. Kiểm tra trước các clip có sẵn phù hợp với phản hồi nhẹ nhàng (ví dụ Laugh chỉ khi có ngữ cảnh cười; không dùng Cheer thường xuyên vì mạnh). Không nhầm các clip locomotion/combat/shooter/vehicle là gesture hội thoại.
4. Nếu không có clip giải thích/lắng nghe tự nhiên, nghiên cứu thêm một clip custom nhẹ (ví dụ Explain: một tay mở nhẹ, vai/thân trên chuyển động nhỏ) trên cùng rig Ara trong nguồn upstream, rồi mới thêm vào pipeline USDZ.
5. Trước khi thiết kế cách phát nhiều gesture, xử lý rõ giới hạn kiến trúc: hiện mỗi USDZ là một Entity/animation riêng; đổi clip đang thay Entity. Cần xác định cách giữ một nhân vật liên tục và chuyển động mượt, không nháy/nhảy pose; không vội tạo hệ thống animation phức tạp.
6. Khi đã có gesture assets phù hợp, mới nối trạng thái nghe/suy nghĩ/nói và các đoạn transcript với gesture. Phải giữ nguyên phát audio, API, lịch sử chat; không sửa Text Chat/Chibi Chat.
7. Kiểm tra kỹ nội dung GLB/rig và log trước khi sửa; không tạo lại asset hoặc chạy Actions chỉ để thử phỏng đoán.

## Việc cần làm khi tiếp tục chat mới
- Đọc file này trước; đây là nguồn bối cảnh chuẩn để tiếp tục, không yêu cầu user kể lại hai repo và pipeline.
- Tiếp tục nghiên cứu bộ 70 animation và kiến trúc RealityKit hiện có; đề xuất phương án ít thay đổi nhất cho cử chỉ Ara tự nhiên, nhẹ nhàng.
- Chưa có yêu cầu sửa code hoặc chạy build trong giai đoạn nghiên cứu hiện tại.

## Đã loại bỏ khỏi ChatAI
- Đã xóa `ChatAI/ChatAIHead3DView.swift`, phần triển khai SceneKit cũ có tham chiếu `Model-02.usdz`.
- Đã bỏ exclusion tương ứng khỏi `project.yml`.
- Không còn tích hợp Model-02 trong luồng Chat Voice.
