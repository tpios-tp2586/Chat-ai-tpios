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
- Không thay chatbot/voice pipeline để làm cử chỉ. Không sửa Text Chat hoặc Chibi Chat khi làm Ara.

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
  6. `scripts/split-glb-animations.mjs` ghép Idle/Wave/Talk/TalkExplain thành một animation tuần tự trên timeline chung; xuất `animation-timeline.json`; convert một USDZ.
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
- Pinned commit dùng cho pipeline Ara: `e26cdef1464a0babf23bb0235b5f05930301ee25`.
- `docs/animations.md` công bố 70 animation clips. Log GLB từ lần test 40979770161 xác nhận đúng 70 animations, 1 skin và 69 joints.
- 70 clips gồm Idle/Crouch idle; locomotion (Walk, Slouch walk, Run, Walk backwards, Strafe); Jump/Fall/Punch/Hit/Reactions; Emotes (Wave, Cheer, Laugh, Talk, Cry); Sit/Lie/Sleep; Turns; shooter; vehicle animations.
- Nguồn có code clip để mở rộng/chỉnh sửa: `src/core/anim/clips/`, gồm `basic.ts`, `actions.ts`, `emotes.ts`, `faces.ts`, `speech.ts`, `index.ts` và các bộ clip khác.
- `Talk` upstream ban đầu không có cử chỉ tay giải thích: nó dựa trên Idle, thêm chuyển động nhẹ ở cổ/đầu theo stress và brow; phần speech face phát viseme giả lập cho preview.
- `Wave` là cử chỉ chào; `Cheer` khá mạnh/phóng đại; `Laugh` là cử chỉ cười rõ. Không dùng các clip locomotion/combat/shooter/vehicle như gesture hội thoại.
- Tài liệu upstream mô tả 34 blend shapes: 20 biểu cảm + 14 speech visemes. Đây là khả năng của nguồn GLB; không đồng nghĩa app hiện tại đang điều khiển viseme theo audio thật.
- License cần giữ đúng: source code Ara 3D Gen MIT; MakeHuman character assets CC0 1.0; motion capture CMU có điều khoản riêng: được dùng kể cả sản phẩm thương mại nhưng không được bán lại riêng dữ liệu motion capture đã chuyển đổi; giữ acknowledgement theo tài liệu nguồn.

### 3. Kiến trúc animation và giới hạn đã xác minh
- Pipeline ban đầu chỉ lấy `Idle`, `Wave`, `Talk` từ 70 animation; không phải upstream chỉ có 3 chuyển động.
- `AraAvatarView.swift` đã được chuyển sang dùng một resource `Ara-Avatar.usdz` và tra animation bằng `availableAnimations`, thay vì duy trì 3 USDZ entity riêng.
- RealityKit có thể nhập USDZ nhiều SkelAnimation thành một resource tên `global scene animation`; không thể giả định giữ tên clip gốc. Apple hỗ trợ cắt một timeline bằng `AnimationView` (`trimStart`/`trimEnd`) rồi tạo các `AnimationResource` riêng.
- Dùng một animation timeline nối tiếp giúp tránh đóng gói 4 bản model đầy đủ; app tạo 4 clip Idle/Wave/Talk/TalkExplain từ resource toàn cảnh và phát trên cùng Entity.
- RealityKit có giới hạn về việc chạy đồng thời nhiều animation trên một Entity; các clip exporter của upstream chứa full-rig tracks, vì vậy không giả định có thể layer Talk + Wave/Explain một cách an toàn.
- `CompanionChatView.swift` theo dõi transcript live và trạng thái `aiSpeaking`; khi đang nói có thể chọn cue theo cụm từ để kích hoạt gesture. Transcript/Audio không có word-level timestamps nên không đồng bộ gesture đến từng âm tiết.

## Quy trình USDZ trong ChatAI — trạng thái hiện tại
- Workflow chính: `.github/workflows/generate-ara-usdz.yml`, chạy thủ công trên `main`.
- Scripts: `scripts/verify-glb.mjs`, `scripts/split-glb-animations.mjs`, `scripts/compact-glb-primitives.mjs`, `scripts/apply-ara-talk-explain.mjs`.
- Workflow checkout `olatunde85/3d-gen` tại pinned commit, tạo GLB, verify rig/animations, áp dụng gesture custom, sau đó split/compact, convert USDZ, inspect/probe và upload artifact.
- Run 41041470989 (`Generate Ara USDZ avatar assets`, 2026-10-30) — pipeline cũ tạo GLB và 3 USDZ SUCCESS.
- Sau đó pipeline được mở rộng với gesture `TalkExplain`. Patch theo hunk số dòng nhiều lần không áp dụng được trên runner; nguyên nhân là patch phụ thuộc vị trí dòng của source upstream.
- Đã thay patch bằng `scripts/apply-ara-talk-explain.mjs`, chỉnh source bằng các anchor code chính xác và kiểm tra mỗi anchor xuất hiện đúng một lần, đồng thời chống chèn trùng `TalkExplain`.
- Workflow được cập nhật để gọi script mới thay cho `git apply` patch.
- Commit script: `83b0790c4c0cf604ed5f2e00b788bf57d1b59351`.
- Commit workflow: `e50bc2174bdf1b8638b6e93f22de98830fdf8982`.
- GitHub Actions run mới nhất: `41072830971`, workflow `Generate Ara USDZ avatar assets`, `workflow_dispatch`, branch `main`, kết luận `success`.
- Run `41072830971` xác nhận cách áp dụng `TalkExplain` mới đã chạy thành công trên GitHub runner; không còn lỗi `git apply` ở bước gesture.
- Artifact run `41072830971` đã được tải và kiểm tra trực tiếp: GLB đầu vào có 71 animations (gồm 4 clip cần dùng), 1 skin, 69 joints; thời lượng clip: Idle 3.2s, Wave 1.6s, Talk 6.4s, TalkExplain 2.8s.
- USDZ của run `41072830971` báo `skelAnimations: 4`, `endTimeCode: 192`, nhưng iPhone thực tế chỉ nhập `(1): global scene animation`; mọi lệnh tìm Idle/Wave/Talk đều Missing. Đây là bằng chứng pipeline cũ không giữ các clip thành tài nguyên có tên riêng khi RealityKit import.
- Apple WWDC21 và API docs xác nhận hướng phù hợp: ghép clip nối tiếp trên một timeline, sau đó dùng `AnimationView` để cắt clip theo timecode. Tổng thời lượng mới dự kiến 14.0s (420 timecodes ở 30fps).
- `TalkExplain`: clip one-shot khoảng 2.8 giây, cử chỉ tay phải mở nhẹ và phối hợp với chuyển động Talk; có mapping facial speech tương ứng. Đây là gesture hội thoại nhẹ, không phải cử chỉ phóng đại.
- Codemagic chưa được coi là đã xác minh cho artifact mới chỉ dựa trên GitHub Actions. Cần build IPA và kiểm tra trên iPhone thật trước khi kết luận Ara hoạt động hoàn chỉnh.
- Đã cập nhật pipeline trên `main` để tạo một animation tuần tự 14s, xuất manifest `animation-timeline.json`, yêu cầu USDZ có đúng `skelAnimations: 1` và `endTimeCode: 420`; upload/release kèm manifest.
- `AraAvatarView.swift` đã chuyển sang đọc manifest và tạo các `AnimationResource` bằng `AnimationView` từ resource `global scene animation`; có kiểm tra thời lượng USDZ trước khi tạo clip.
- `codemagic.yaml` đã kiểm tra và bundle cả `Ara-Avatar.usdz` lẫn `animation-timeline.json`; ZIP chỉ là file tạm nội bộ, artifact build vẫn chỉ là IPA.
- Các commit sửa mới trên `main`: script timeline `172c87f4c7ebc51902cdda8c6e851dfb5e153f6e` và kiểm tra metadata track `f73ba809c1f3dd8a7d564a84dc76b29dd99e29da`; workflow `971b16f1ab5486c182c01d9eb56bbed59b7a9cfa` and assertion `f6dee0ab63cf01c03df3e8c4e3d816279acbdbae`; Swift `b0f084852d6009f8f66824524eda9e1c5f82aa39`; Codemagic `f2d7abfe68602b32f74733d47d8ad48f9d776872`.
- Đã test script ghép timeline trực tiếp trên GLB artifact thật: tạo một animation `AraConversation`, 71 channels, tổng 14.0s; manifest có đúng các khoảng Idle 0–3.2s, Wave 3.2001–4.8s, Talk 4.8001–11.2s, TalkExplain 11.2001–14.0s. Kiểm tra header GLB và cấu trúc channel thành công.
- Chưa chạy lại GitHub Actions vì connector hiện không có thao tác dispatch workflow; thay đổi conversion chưa được xác minh trên macOS/usdzconvert. Chưa build Codemagic hoặc test IPA mới.

## Hướng triển khai Ara hiện tại
1. Giữ `Idle` làm chuyển động nền; `Talk` làm chuyển động nền khi phát audio.
2. `Wave` chỉ dùng lúc chào và tránh lặp quá dài.
3. `TalkExplain` dùng cho một số cue hội thoại như giải thích, ví dụ, tóm lại, quan trọng là; chỉ kích hoạt tối đa một lần trong một lượt nói.
4. Không cố đồng bộ gesture theo từng âm tiết vì transcript và audio không có word-level timestamps.
5. Tiếp tục ưu tiên chuyển động tự nhiên, nhẹ nhàng, nữ tính; tránh lặp gật đầu/nhìn quanh hoặc động tác quá mạnh.
6. Khi test trên thiết bị, kiểm tra liên tục entity, transition, animation name, texture và resource loading; không chỉ dựa vào việc Actions SUCCESS.
7. Giữ nguyên chatbot, API, lịch sử chat, audio/voice pipeline; không sửa Text Chat và Chibi Chat.

## Đã loại bỏ khỏi ChatAI
- Đã xóa `ChatAI/ChatAIHead3DView.swift`, phần triển khai SceneKit cũ có tham chiếu `Model-02.usdz`.
- Đã bỏ exclusion tương ứng khỏi `project.yml`.
- Không còn tích hợp Model-02 trong luồng Chat Voice.

## Việc cần làm khi tiếp tục chat mới
- Đọc file này trước; đây là nguồn bối cảnh chuẩn để tiếp tục, không yêu cầu user kể lại hai repo và pipeline.
- Bước tiếp theo: chạy thủ công workflow `.github/workflows/generate-ara-usdz.yml` trên `main`; kiểm tra log conversion phải có `skelAnimations: 1`, `endTimeCode: 420`, probe=`1`, artifact phải gồm `Ara-Avatar.usdz` và `animation-timeline.json`.
- Nếu Actions thành công, chạy Codemagic để build IPA. Kiểm tra iPhone: log phải báo tạo 4 `AnimationViews` từ global scene animation, duration khoảng 14s, sau đó phát Idle/Talk/Wave/TalkExplain không còn Missing.
- Nếu Actions báo USDZ duration không đúng 14s hoặc không tạo được đúng 1 SkelAnimation, dừng và sửa converter trước khi build app.
- Chỉ sau khi kiểm tra thiết bị mới đánh giá tiếp chất lượng gesture và quyết định có cần chỉnh code hay asset.

## Cập nhật sau build và kiểm tra hành động Ara — 2026-10-31
### Đã xác nhận trên iPhone
- User đã test bản build mới: kéo xoay Ara và pinch-to-zoom đều hoạt động đúng.
- Xoay ngang bằng một ngón và thu phóng bằng hai ngón được giữ lại làm chức năng đã kiểm chứng; không cần coi đây là việc đang chờ triển khai.
- Commit thêm tương tác xoay và tự quay về chính diện khi bắt đầu Talk: `2d4f1cd172ae8ed17bcf6d5f6f749b54d00e5853`.
- Việc xoay/zoom đã được user xác nhận chạy đúng; các hành động animation theo ngữ cảnh bên dưới vẫn cần đánh giá riêng, không suy ra là đã hoạt động chỉ từ test xoay/zoom.

### Audit luồng gọi hành động hiện tại — đọc code main
- `LiveVoiceManager.handle()` đặt `aiSpeaking = true` khi nhận chunk âm thanh đầu ra từ Gemini; đặt false khi nhận `turnComplete` hoặc `interrupted`. `CompanionChatView` dùng trạng thái này để chọn `Talk`/ `Idle`. Đây là đường gọi chính của animation nói.
- `Wave` được gọi khi trạng thái cuộc gọi chuyển sang `live`; sau 1,6 giây tự về `Idle` nếu cuộc gọi vẫn live và AI chưa nói. Đây là cử chỉ chào lúc kết nối, không phải cử chỉ phản hồi theo từng câu.
- `TalkExplain` chỉ được gọi khi transcript assistant đang nói chứa một trong các cụm cue hard-code: `để em giải thích`, `để em nói rõ`, `đầu tiên`, `ví dụ`, `cụ thể là`, `tóm lại`, `quan trọng là`, `let me explain`, `for example`, `in summary`. Mỗi lượt assistant chỉ cho chạy một lần theo cờ `didTriggerExplainGesture`; timer 2,8 giây dự kiến đưa về `Talk` nếu AI vẫn nói.
- `AraAvatarLoader.show()` lưu clip được yêu cầu khi USDZ chưa nạp xong; sau khi tạo 4 AnimationViews, nó phát clip mới nhất. Khi đã nạp, clip được ánh xạ bằng tên lowercase từ enum: `idle`, `wave`, `talk`, `talkExplain`. Không thấy đường gọi nhầm tên clip trong mapping hiện tại.
- Các clip hiện được phát thay thế nhau trên cùng Entity, không layer đồng thời; phù hợp giới hạn full-rig tracks đã ghi ở trên.

### Các điểm đang bị bỏ qua hoặc chưa nối vào Ara
- `CompanionEmotion` (listening/thinking/happy/surprised...) hiện chỉ điều khiển dòng trạng thái và icon giao diện; không điều khiển animation hay blendshape của Ara.
- `LiveVoiceManager.faceExpression` được cập nhật trong luồng Gemini (thinking/listening/speaking/mood), nhưng `CompanionChatView` không đọc thuộc tính này để điều khiển Ara. Vì vậy các mood này hiện không truyền sang avatar 3D.
- Những cue cảm xúc như vui, ngạc nhiên, đùa, buồn, giận... không có clip tương ứng trong `AraAvatarView.Clip`; phần nhận diện chữ chỉ đổi trạng thái UI.
- Khi người dùng đang nói/nghe, Ara hiện chủ yếu giữ `Idle`; chưa có hành động nghe chủ động hoặc suy nghĩ riêng. `Talk` cũng chỉ là clip nguồn có chuyển động đầu/cổ nhẹ; không có cử chỉ tay liên tục.
- `TalkExplain` dựa vào khớp cụm từ trên transcript, không có timestamp từ audio; do đó gesture có thể bắt đầu trễ/sớm so với câu nói, và có thể không kích hoạt nếu AI diễn đạt khác các cụm cue.
- Có một rủi ro timing cần xử lý khi chỉnh tiếp: callback 2,8 giây của một lần `TalkExplain` chỉ kiểm tra `aiSpeaking` và clip hiện tại. Nếu một lần `TalkExplain` mới bắt đầu trước khi callback cũ chạy, callback cũ có thể kết thúc nhầm lần mới. Chưa tái hiện trên thiết bị; đây là rủi ro logic từ code.
- Không có bằng chứng hiện tại cho thấy các clip bị gọi nhầm tên; vấn đề chính là số hành động được nối vào Ara còn ít, mood bị bỏ qua, và cue phụ thuộc văn bản/timing.

### Hướng audit/triển khai tiếp theo
1. Giữ nguyên tương tác xoay/zoom đã test thành công.
2. Trước khi thêm cử chỉ mới, xử lý rủi ro callback cũ của `TalkExplain` bằng định danh lượt/Task cancellation để không thể ghi đè clip của lượt mới.
3. Thiết kế mapping rõ ràng giữa trạng thái nghe/suy nghĩ/nói/chào và các clip thực có trong USDZ; không gọi các mood UI là biểu cảm 3D khi chưa có mapping.
4. Đánh giá riêng phương án cho happy/surprised và gesture nghe/suy nghĩ; hiện chưa có animation phù hợp được nối vào runtime.
5. Không sửa voice pipeline, Text Chat, Chibi Chat hoặc asset animation khi chưa xác định clip/rig cần dùng. Ưu tiên sửa tối thiểu và kiểm tra bằng log trên iPhone.

- Bổ sung sau khi rà thứ tự cập nhật SwiftUI: có trường hợp `onChange(of: clip)` không nhận được trạng thái trung gian `.talk`. Trong cùng callback `aiSpeaking = true`, code gán `.talk` rồi gọi `handleLatestTranscript()`; nếu transcript đã có cue, hàm này gán ngay `.talkExplain`. SwiftUI có thể render giá trị cuối cùng `.talkExplain` và bỏ qua trạng thái `.talk`, vì vậy logic reset góc nhìn đang gắn riêng với `newClip == .talk` không bảo đảm chạy ở mọi lượt nói. Nên chuyển reset về tín hiệu bắt đầu nói độc lập với lựa chọn clip (ví dụ token/reset event), nhưng chưa sửa trong lượt audit này.
