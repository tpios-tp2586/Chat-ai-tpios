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
- Scripts: `scripts/verify-glb.mjs`, `scripts/split-glb-animations.mjs`, `scripts/compact-glb-primitives.mjs`, `scripts/apply-ara-talk-explain.mjs`, `scripts/inspect-ara-animation.mjs`.
- Workflow checkout `olatunde85/3d-gen` tại pinned commit, tạo GLB, verify rig/animations, áp dụng gesture custom, phân tích track GLB, sau đó split/compact, convert USDZ, inspect/probe và upload artifact.
- Run 41072830971 (`Generate Ara USDZ avatar assets`, 2026-10-30) — pipeline cũ tạo GLB và USDZ SUCCESS; nó dùng bản pipeline 4 clip trước khi timeline 8 clip hiện tại.
- `TalkExplain` patch hiện dùng source anchor chính xác thay cho `git apply` theo dòng.
- GLB run 41072830971 xác nhận upstream sau patch có 71 animations, 1 skin, 69 joints; `TalkExplain` 2.8s.
- Run 41072830971 còn cho một dữ liệu quan trọng: `usdzconvert` cảnh báo `Skeletal animation contains node animation` cho các animation. Cần không suy đoán ý nghĩa trên iPhone; pipeline mới phải kiểm tra track dữ liệu trước và sau conversion.
- Đã test script ghép timeline trên GLB artifact thật: tạo một animation `AraConversation`, 71 channels, tổng 14.0s trong bản 4 clip cũ. Bản hiện tại đã mở rộng lên 8 clip và 26.0s.
- Workflow hiện tại yêu cầu USDZ có đúng một SkelAnimation, `endTimeCode=780` và 30 fps; app cắt 8 `AnimationView` từ timeline 26s.
- Codemagic chưa được coi là đã xác minh cho asset mới chỉ dựa trên GitHub Actions. Cần build IPA và kiểm tra trên iPhone thật trước khi kết luận Ara hoạt động hoàn chỉnh.

## TalkExplain — điều kiện kích hoạt và nghiên cứu animation — 2026-10-31
- Runtime đã xác nhận TalkExplain được kích hoạt và phát đúng: log có `TalkExplain triggered: cue=dau tien`, `Playing TalkExplain from the global timeline`, `Đang phát animation TalkExplain`, sau đó `TalkExplain finished; returned to Talk`.
- Quan sát iPhone: TalkExplain không tạo gesture tay nhìn thấy; Ara vẫn chủ yếu gật/xoay đầu giống Talk. User cũng ghi nhận thỉnh thoảng tay phải giơ nhanh rồi hạ xuống như trước.
- Không tiếp tục chỉnh transcript trigger. Vấn đề cần phân biệt bằng dữ liệu là: (A) GLB TalkExplain không có/không đủ khác biệt ở joint tay; (B) GLB có track nhưng USDZ conversion làm mất/đổi track; hoặc (C) USDZ/RealityKit import/playback có track nhưng không áp dụng đúng.
- Đã thêm `scripts/inspect-ara-animation.mjs` để phân tích trực tiếp GLB được generate trong workflow: số channel/path, duration, sự tồn tại của track `RightShoulder/RightArm/RightForeArm/RightHand` và các ngón, đồng thời tính `maxAngleDeltaVsTalk` cho các joint quan trọng.
- Workflow `generate-ara-usdz.yml` hiện chạy diagnostic ngay sau khi generate GLB và đưa `animation-diagnostics.txt` vào artifact/release cùng USDZ.
- Mục tiêu của lần test tiếp theo: **một workflow run phải trả lời bằng dữ liệu** TalkExplain có thực sự khác Talk ở chain tay phải hay không; không sửa gesture lần nữa trước khi có số đo này.

## Đóng gói IPA
- Codemagic workflow `ios-unsigned` là đường build IPA chính; assistant không có thao tác dispatch Codemagic trực tiếp.
- Artifact GitHub Actions được Codemagic tải phải chứa `Ara-Avatar.usdz` và `animation-timeline.json` đồng bộ cùng run.
- Sau khi có asset run mới, build IPA trên `main`, cài iPhone thật và đối chiếu log TalkExplain với `animation-diagnostics.txt`.
- ZIP chỉ là file tạm nội bộ của workflow; artifact cuối mong muốn vẫn chỉ IPA.

## USDZ post-conversion joint diagnostics — 2026-10-31
- Latest successful run 41192273828 confirmed GLB `TalkExplain` differs strongly from `Talk` in arm joints: RightArm 49.729°, RightForeArm 103.471°, RightHand 37.736° (sampled quaternion delta); Head 0.822°, Neck 0.345°.
- The same run converted USDZ successfully, retaining 1 UsdSkel animation, 780 timecodes at 30 fps, and 34 morph targets. Converter emitted `Skeletal animation contains node animation` plus unresolved generated texture references; neither warning alone proves arm animation loss.
- Added `scripts/inspect-ara-usdz-animation.py` to read actual `UsdSkel.Animation` joint rotation arrays from the converted USDZ and sample Talk/TalkExplain at matching normalized times. It reports max angular difference and maximum angular range from each clip's starting pose for torso/head/right-arm joints.
- Updated `.github/workflows/generate-ara-usdz.yml` to run this diagnostic after conversion and include `usdz-animation-diagnostics.txt` in the USDZ artifact and release.
- Next: run the workflow on `main` and compare the new USDZ report against `animation-diagnostics.txt`. Do not build Codemagic IPA until post-conversion results are reviewed.
\n

## Ara playback handoff — 2026-10-31
- Code review found AraAvatarLoader.play() replaced its stored AnimationPlaybackController without explicitly stopping the previous controller. This left the runtime handoff insufficiently observable and potentially allowed overlapping full-rig playback.
- Updated ChatAI/AraAvatarView.swift on main (commit e72ae2231d094de48b108750e3e89d6b3f718a85): before starting a new clip, inspect the previous controller and stop it if still valid; then log the new controller's isPlaying, isValid, and duration. This keeps one intended clip active at a time; it does not change the USDZ, timeline, clip ranges, trigger cues, or voice pipeline.
- Apple RealityKit documents controller stop/stop-with-blend-out and notes that up to two animations can blend on an entity. The app targets iOS 16, so the implementation uses the broadly available controller stop() API and retains the existing 0.25s transition for the next clip.
- Runtime verification is still required on a real iPhone. Expected diagnostic sequence when switching Talk → TalkExplain → Talk: previous controller status, previous playback stopped, then new clip started with playing=true and valid=true. If the logs show this but the arm gesture remains visually weak, the remaining issue is the gesture's authored motion amplitude/pose rather than clip selection or overlapping playback.
- Do not modify Text Chat, Chibi Chat, or voice transport. Do not build/dispatch Codemagic until user requests the next test.
