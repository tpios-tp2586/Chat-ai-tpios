# ChatAI — Project Checkpoint

## Repository và quy tắc
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trực tiếp trên `main`; không tạo/chuyển branch.
- Trước khi sửa: kiểm tra HEAD, đọc checkpoint và source thực tế.
- Ưu tiên diff nhỏ, Ponytail; không thêm dependency.
- Không sửa chatbot/API, chat history, `LiveVoice.swift`, Gemini Live/voice pipeline, Text Chat hoặc Chibi Chat khi làm Ara.
- Không tự chạy Codemagic hoặc GitHub Actions. Người dùng tự build IPA.
- `PROJECT_STATUS.md` là checkpoint duy nhất.

## Trạng thái hiện tại — Ara đứng yên, xóa code hành động và TEST (2026-11-04)
- **Mục tiêu hiện tại:** Ara chỉ nạp model USDZ và giữ nguyên tư thế nhập vào; không có chuyển động tự động, animation theo trạng thái thoại, clip hành động, popup TEST hoặc TEST tổng hợp.
- `ChatAI/AraAvatarView.swift`: đã bỏ enum Clip, timeline parser, AnimationView/AnimationResource generation, AnimationPlaybackController và mọi lệnh phát animation. Loader chỉ nạp model; log số/tên animation nhúng trong asset nhưng không kích hoạt chúng.
- `ChatAI/CompanionChatView.swift`: đã bỏ nút TEST, popup, danh sách clip, batch, task test, thời lượng clip và toàn bộ logic chuyển trạng thái voice thành clip Ara. Các trạng thái cảm xúc còn lại chỉ cập nhật nhãn/trạng thái chữ của giao diện, không điều khiển avatar; đã bỏ cả thuộc tính label cũ không còn dùng.
- Nút LOG và Sao chép log được giữ. Log có prefix `[ARA STATIC]` để ghi nhận asset được nạp, số/tên animation nhúng (nếu có), và xác nhận app không tạo hoặc phát animation.
- Zoom và xoay bằng thao tác người dùng chỉ thay đổi góc nhìn camera/model root; không phải animation hay hành động tự động của Ara.
- USDZ gốc vẫn chứa animation data. Đây là dữ liệu nguồn bất hoạt trong app hiện tại, không phải code phát hành động. Không chỉnh/xóa dữ liệu USDZ hoặc pipeline tạo asset trong bước này.
- Source commits: `d9e2c7fbb9d99a7c50a50d4224b715e997b9e62d` (static loader và bỏ playback); `f52991ce79ddf19deca25041c7c8d90c42bf6e58` (xóa TEST/action orchestration khỏi Chat Voice); `0177f6686367177ff3a93d596fa3995f9c5705f0` (log xác nhận chế độ tĩnh); `4d77bbff62a26246ad9346e354bcbd5d65423c9a` (dọn trạng thái cảm xúc chỉ còn phục vụ nhãn giao diện).
- Chưa build/chưa kiểm chứng trên iPhone. Không tuyên bố đã xác nhận đứng im hoàn toàn cho đến khi người dùng build IPA và quan sát trực tiếp.

## Lịch sử kiểm thử hành động Ara — đã hoàn tất, không tái sử dụng
- Đợt kiểm thử trước dùng batch 30 clip, theo timeline: Idle; Wave; Talk; TalkExplain; AraListening; AraThinking; AraEmpathy; AraLaugh; Walk; Run; Walk backwards; Strafe left; Strafe right; Jump start; Jump (in air); Jump land; Sit down (chair); Sit idle (chair); Stand up (chair); Lie down; Sleep; Turn left 45°; Turn left 90°; Turn right 45°; Turn right 90°; Full turn 360°; Ride horse (trot); Cheer; Laugh; Cry.
- Log trước đây xác nhận các clip được gọi và bắt đầu phát theo thứ tự; người dùng đã quan sát thực tế và xác định một số hành động không hoạt động/không phù hợp. Đợt test hành động này được đóng lại theo yêu cầu người dùng; không giữ lại popup, nút, batch hoặc logic test.
- Các lần rút xuống 11 clip và điều phối Talk/Listening/Thinking/Idle sau đó chỉ là bước trung gian. Toàn bộ test và điều phối animation đó đã bị thay thế bởi chế độ Ara đứng yên hiện tại.

## Quy trình xác minh mới
1. Người dùng build IPA từ `main`.
2. Mở Chat Voice, quan sát Ara trong trạng thái ban đầu, khi kết nối, khi AI nói, khi nghe và sau khi kết thúc phiên. Ara phải giữ nguyên tư thế, không cử động theo bất kỳ trạng thái nào.
3. Mở LOG và sao chép. Kiểm tra có `[ARA STATIC]` ghi asset nạp thành công và playback bị vô hiệu hóa; không còn log `[ARA TEST]` hoặc `[ARA] Playback started`.
4. Nếu avatar vẫn tự chuyển động dù source không còn code phát animation, điều tra khả năng animation tự chạy từ asset/import/runtime trước khi sửa tiếp. Không thêm test UI mới.
5. Chỉ sau khi xác nhận Ara đứng yên hoàn toàn mới thiết kế bộ hành động phục vụ hội thoại thực tế. Khi đó hành động được tích hợp trực tiếp vào luồng trò chuyện và đánh giá qua hội thoại thật, không tạo một hệ thống test hành động riêng.

## Ara — kết quả nghiên cứu kỹ thuật đã xác minh (2026-11-02)

> Mục đích: lưu toàn bộ kết quả nghiên cứu để các phiên làm việc sau đọc checkpoint là có thể tiếp tục, không phải tải artifact hoặc nghiên cứu lại từ đầu. Đây là kết quả phân tích, **chưa phải thay đổi code**.

### Nguồn và khả năng truy vết
- Nguồn artifact: GitHub Actions workflow run `41314736856`, commit nguồn `74b648cad35672beb093149a8c9a1e32184abdd9`, run thành công ngày 2026-11-01.
- Artifact ID: `13086787045`; gói nghiên cứu đã tải và phân tích: `ara-avatar-research-bundle.zip`.
- Model generator: repo `olatunde85/3d-gen`, commit `e26cdef1464a0babf23bb0235b5f05930301ee25`.
- GLB nguồn: `Athletic_woman.glb`, 17,534,748 bytes, SHA256 `5e922c88cb665593ab4c47973b6368df0205996f24290654a83d38cb47dd2e1e`.
- USDZ: `Ara-Avatar.usdz`, 26,650,207 bytes, SHA256 `93d8e5fa11715eb10c56179209fdf57fcb371cc2b26008f7ee143489e0b552e2`.
- Gói artifact có các báo cáo `usdz-report.txt`, `usdz-animation-diagnostics.txt`, `animation-diagnostics.txt`, `animation-timeline.json`, `verification-report.txt`, `texture-diagnostics.txt`, `conversion-log.txt` và `ara-research-data.json.gz`.
- Khi cần kiểm chứng lại, ưu tiên artifact/run/commit nêu trên; không cần yêu cầu người dùng tải hoặc gửi lại log/model nếu connector vẫn truy cập được.

### Kết quả model và chuyển đổi GLB → USDZ
- GLB có 1 skin, 69 joints, 34 morph targets và 75 animations.
- USDZ giữ được 69 joints, toàn bộ 34 BlendShapes; dữ liệu animation có 1,802 mẫu blendShape weights và 1,802 mẫu joint translation/rotation. Không có scale samples.
- Kết luận quan trọng: **quá trình chuyển GLB sang USDZ không làm mất 34 morph targets**. Có thể dùng BlendShapes trên model USDZ hiện tại; không cần tạo lại model chỉ vì nghi ngờ mất blendshape.
- USDZ có một skeletal animation toàn cục; timeline 0–3539.001953125 timecodes ở 60 timeCodes/giây, tương đương khoảng 58.983 giây. Log app báo 30 clip được cắt từ global scene animation.
- GLB có các node `Jaw`, `LeftEye`, `RightEye`, `Head` và skeleton 69 joints.
- 34 BlendShape theo đúng tên:
  `eyeBlinkLeft`, `eyeBlinkRight`, `eyeWideLeft`, `eyeWideRight`, `eyeSquintLeft`, `eyeSquintRight`,
  `browDownLeft`, `browDownRight`, `browInnerUp`, `browOuterUpLeft`, `browOuterUpRight`,
  `jawOpen`,
  `mouthSmile`, `mouthFrown`, `mouthPucker`, `mouthPress`, `mouthStretch`, `mouthUpperUp`,
  `noseSneerLeft`, `noseSneerRight`,
  `viseme_PP`, `viseme_FF`, `viseme_TH`, `viseme_DD`, `viseme_kk`, `viseme_CH`, `viseme_SS`, `viseme_nn`, `viseme_RR`, `viseme_aa`, `viseme_E`, `viseme_I`, `viseme_O`, `viseme_U`.
- Một số khoảng giá trị được xác minh từ dữ liệu: `jawOpen` 0–0.55; `mouthSmile` 0–1; `mouthFrown` 0–0.8; `eyeBlinkLeft/Right` 0.16–1.0; `browInnerUp` 0–1. Đây là biên quan sát trong animation/model hiện có, không mặc định là giới hạn API bắt buộc.

### Nội dung các animation đã xác minh
- `Idle`: có chớp mắt.
- `Wave`: có squint mắt (0.25), nâng chân mày ngoài (0.20), cười (mouthSmile 0.70).
- `Talk`: chuyển động 69 joints và BlendShape gồm chớp mắt, chân mày và chuỗi viseme PP, FF, TH, DD, kk, SS, nn, RR, aa, E, I, O, U.
- `TalkExplain`: cũng có chuyển động toàn bộ rig và BlendShape/viseme; không phải animation chỉ riêng cánh tay.
- `AraListening`, `AraThinking`, `AraEmpathy`, `AraLaugh`: chủ yếu có chớp mắt, không có các morph biểu cảm khuôn mặt rõ rệt trong dữ liệu đã phân tích.
- `Cheer`: squint 0.3, jawOpen 0.4, mouthSmile 0.9.
- `Laugh`: có biểu cảm cười rõ: squint mắt, nâng chân mày ngoài, jawOpen khoảng 0.2–0.55, mouthSmile 1.0, mouthUpperUp khoảng 0.3–0.5.
- `Cry`: squint mắt, browInnerUp 1.0, jawOpen khoảng 0.1–0.24, mouthFrown 0.8, mouthStretch khoảng 0.25–0.46.
- `Talk` dài khoảng 6.4 giây; `TalkExplain` khoảng 2.8 giây. Các giá trị thời lượng này là clip đã cắt trong timeline hiện tại.

### Vấn đề đã xác định trong code hiện tại
- Đã đọc các file `ChatAI/AraAvatarView.swift`, `ChatAI/CompanionChatView.swift`, `ChatAI/LiveVoice.swift`, `ChatAI/FaceView.swift` cùng script/workflow liên quan.
- `AraAvatarView.swift` tải `Ara-Avatar.usdz`, lấy animation resource từ global scene animation rồi cắt timeline thành các clip. Khi chuyển clip, code dừng `AnimationPlaybackController` trước đó; transition cố định khoảng 0.25 giây.
- Loader hiện tại chưa thể hiện một facial BlendShape controller độc lập rõ ràng; hiện chủ yếu phát các clip animation toàn cục đã cắt.
- Trong `CompanionChatView.swift`, nhiều luồng độc lập cùng ghi `avatarClip`: trạng thái voice, AI speaking, transcript, emotion cue, explain cue, empathy/laugh và TEST. Có generation UUID/cancellable task để ngăn tác vụ cũ, nhưng nhiều nơi cùng quyết định clip vẫn có thể gây tranh chấp thứ tự và ghi đè animation.
- `onChange(of: liveManager.lines.last?.text)` xử lý transcript theo từng lần cập nhật; `onChange(of: liveManager.lines.count)` cũng reset turn flags và gọi xử lý transcript.
- Khi `liveManager.aiSpeaking` đổi trạng thái, nhánh bắt đầu nói phát `.talk`; khi dừng nói, nhánh này hủy gesture task và chọn `.listening` hoặc `.idle`. Vì vậy nó có thể ghi đè gesture/biểu cảm khác nếu các luồng xảy ra gần nhau.
- **Sai mapping tiếng cười cần lưu ý:** `playAraLaugh()` trong `CompanionChatView.swift` đặt `avatarClip = .laugh`; nhưng `.laugh` trong `AraAvatarView.Clip` ánh xạ tới clip `AraLaugh` (dữ liệu chủ yếu chớp mắt, không có mouthSmile rõ). Clip `Laugh` riêng biệt mới có morph cười rõ và được ánh xạ bởi `.naturalLaugh`. Đây là ứng viên sửa mapping sau khi người dùng duyệt; chưa sửa.
- Không được nhầm hệ thống mặt robot 2D trong `FaceView.swift` với BlendShape 3D của Ara.

### Đồng bộ khẩu hình với giọng Gemini Live
- `LiveVoice.swift` cấu hình Gemini Live trả audio và `outputAudioTranscription`; app nhận các mảnh transcript tăng dần và các chunk PCM 24 kHz để phát âm thanh.
- Nghiên cứu code hiện tại không thấy timestamp phoneme/viseme đi kèm luồng audio/transcript. Vì vậy chuỗi viseme dựng sẵn trong clip `Talk` chỉ lặp lại theo animation, **không đồng bộ chính xác với âm tiết thực tế** của câu trả lời.
- Có thể lấy biên độ/RMS từ PCM chunk để điều khiển `jawOpen` theo năng lượng âm thanh mà không cần thay thế voice pipeline. Cách này chỉ đồng bộ độ mở miệng theo cường độ âm thanh, không xác định đúng hình miệng của từng âm vị.
- Muốn viseme khớp âm vị thực sự cần phoneme alignment/timing hoặc một cơ chế ước lượng âm vị có thời điểm; transcript chunk hiện tại tự nó không cung cấp đủ timestamp để khớp chính xác.
- Không thay đổi Gemini/PCM/audio queue hoặc voice pipeline chỉ để thử animation. Ưu tiên thử nghiệm ở lớp avatar/facial controller độc lập.

### RealityKit — hướng API đã có tài liệu Apple xác nhận
- Apple Developer sample **BOT-anist** xác nhận RealityKit tự tạo `BlendShapeWeightsComponent` cho ModelEntity được tải từ USDZ có BlendShapes; animation BlendShape trong USDZ được đưa vào `AnimationLibraryComponent`; có thể phát animation USD hoặc cập nhật weights theo cách procedural.
- Apple Developer docs **BlendShapeWeightsComponent** xác nhận component cho phép truy cập/cập nhật weights BlendShape hiện tại.
- **BlendShapeWeightsMapping** được tạo từ MeshResource; cần gán ModelComponent trước và tên weight phải khớp tên BlendShape trong mesh.
- WWDC24 **Compose interactive 3D content in Reality Composer Pro** trình bày BlendShape animation procedural/USD và `SkeletalPosesComponent` cho skinned mesh.
- Các API/tài liệu cần tham chiếu khi triển khai: `BlendShapeWeightsComponent`, `BlendShapeWeightsMapping`, `BindTarget.blendShapeWeightsAtIndex`, `SkeletalPosesComponent`, `AnimationLibraryComponent`.
- Lưu ý: cần xác minh deployment target iOS của project trước khi dùng API; đồng thời kiểm tra runtime entity hierarchy để biết chính xác child ModelEntity nào sở hữu component/mesh BlendShape. Không được chỉ dựa vào việc USDZ có morph targets để kết luận code đã truy cập đúng entity.
- Tài liệu Apple đã tra cứu trong phiên nghiên cứu: Apple Developer BOT-anist sample; BlendShapeWeightsComponent; BlendShapeWeightsMapping; BindTarget.blendShapeWeightsAtIndex; WWDC24 “Compose interactive 3D content in Reality Composer Pro”.

### Kết luận kiến trúc — chỉ là hướng đề xuất, chưa được triển khai
- Nên tách hai trách nhiệm: (1) body animation/state và gesture; (2) facial BlendShape controller độc lập.
- Body state cơ bản: Talk / Listening / Idle. Gesture có ưu tiên rõ ràng: Explain, Wave, empathy, laughter. Chỉ nên có một bộ điều phối quyết định animation để tránh nhiều `onChange` ghi đè lẫn nhau.
- Không mặc định `TalkExplain` là overlay chỉ cho tay: clip này có cả skeletal animation toàn rig và BlendShape tracks. Phát đồng thời với `Talk` có thể xung đột trên cùng joints/BlendShape targets.
- Không mặc định thêm một facial animation song song là an toàn: clip body hiện tại cũng chứa face tracks. Cần xác định cách loại/né face tracks khỏi clip body hoặc kiểm soát layer/target cụ thể trước khi triển khai; nếu chưa giải quyết được xung đột thì tiếp tục dùng clip Talk có sẵn như giải pháp tạm thời.
- Hướng tiềm năng: tạo skeletal-only body clip resources và điều khiển 34 facial weights bằng controller riêng; hoặc tạm thời dùng các clip có sẵn cho đến khi chứng minh được cơ chế blend/layer không xung đột. Chưa chọn cách cuối cùng.
- Tiếng cười tự động có thể đổi sang `Laugh`/`.naturalLaugh` sau khi kiểm tra toàn bộ luồng emotion và được người dùng duyệt.
- Thử nghiệm trước trên màn Ara và log chẩn đoán; giữ nút LOG/Copy Log. Không sửa Text Chat, Chibi Chat, chatbot/API hoặc voice pipeline.

### Trạng thái nghiên cứu và việc tiếp theo
- Đã hoàn thành phân tích asset GLB/USDZ, timeline/clip, mapping laughter, code animation state writers, Gemini Live audio/transcript và hướng API RealityKit.
- **Chưa sửa bất kỳ source code nào; chưa chạy build; chưa dispatch workflow; chưa tạo branch hoặc commit code.** Chỉ đọc repo và tải/phân tích artifact đã có.
- Việc nghiên cứu kỹ thuật tiếp theo nếu được yêu cầu: kiểm tra chính xác runtime entity hierarchy/component trong `AraAvatarView.swift`, deployment target iOS, và cách cắt/điều khiển skeletal-only animation mà không xung đột BlendShape. Đây là bước xác minh trước triển khai, không phải lý do để nghiên cứu lại model/GLB→USDZ.
- Khi tiếp tục ở chat mới: đọc mục này trước; không lặp lại phân tích GLB/USDZ và clip đã xác minh. Chỉ kiểm tra lại nếu asset hoặc commit model thay đổi.



## Ara — hành vi đã test thực tế trên iPhone (2026-11-03)

### TEST thủ công và trò chuyện trực tiếp là hai kết quả khác nhau
- Người dùng đã xác nhận: trong popup TEST, khi tự chọn từng hành động cho Ara thực hiện, **Ara đều thực hiện đúng hành động được chọn**. Các clip/action test thủ công đang hoạt động; không được coi đây là lỗi thiếu animation asset hoặc lỗi không phát được clip.
- Khi vào trò chuyện trực tiếp, hành vi thực tế hiện tại chỉ lặp lại các chuyển động nhỏ:
  1. Toàn thân lắc qua lắc lại khoảng 3°.
  2. Đầu gật/lắc nhẹ qua lại.
  3. Khi mới vào trò chuyện, Ara giơ một tay chào.
  4. Trong lúc AI nói, thỉnh thoảng Ara giơ một tay lên rồi hạ xuống rất nhanh.
- Đây là mô tả hành vi thực tế do người dùng quan sát, không phải suy luận từ asset hoặc log.
- Kết luận chẩn đoán: khả năng phát clip/action riêng lẻ đã được xác nhận bằng TEST; vấn đề cần xử lý nằm ở **logic điều phối/chọn animation trong chế độ trò chuyện trực tiếp** (các state/trigger/clip được chọn và thời điểm ghi đè), không phải tiếp tục kiểm tra lại từng nút TEST.
- Khi điều tra tiếp, tập trung truy vết các luồng ghi `avatarClip` trong `CompanionChatView.swift`, thứ tự ưu tiên giữa Talk/Idle/Listening và gesture, thời lượng/loop/transition của clip trong hội thoại. So sánh clip được gọi khi TEST với clip thực tế được gọi trong live chat.
- Không hỏi người dùng lặp lại các quan sát trên. Không sửa giao diện TEST hoặc làm thay đổi voice pipeline; kiểm tra code và log thực tế trước, rồi đề xuất thay đổi tối thiểu cho animation orchestration.


## Ara — phân tích luồng animation trò chuyện trực tiếp (2026-11-03)

### Đã đối chiếu code trên main sau khi nhận phản hồi thực tế
- HEAD tại thời điểm kiểm tra: `1bea853066eeda249e6ed8d4aaf3a7d553f6fcae`.
- Đã đọc lại `CompanionChatView.swift`, `AraAvatarView.swift` và `LiveVoice.swift`; không sửa voice pipeline.
- TEST thủ công gọi thẳng `testAraGesture(_:) -> avatarClip = clip`, hủy các task gesture cũ và giữ clip chạy đủ duration đọc từ timeline. Điều này phù hợp với xác nhận của người dùng rằng các hành động TEST đều chạy đúng.
- Trong live chat, khi `aiSpeaking` bắt đầu, code luôn đặt `avatarClip = .talk`; khi kết thúc, code hủy gesture task và đặt về `.listening` hoặc `.idle`.
- Cử chỉ hội thoại hiện không chạy theo lịch/chu kỳ. Chúng chỉ được kích hoạt khi heuristic tìm thấy từ khóa trong transcript:
  - `explainCueReason` mới kích hoạt `.talkExplain`, tối đa một lần mỗi lượt assistant, chạy 2.8 giây rồi trở về `.talk`.
  - `contextGestureCue` mới kích hoạt empathy/laugh theo một nhóm từ khóa; task hiện tại giữ 2.4 giây rồi trở về Talk/Listening/Idle.
  - Vì vậy câu trả lời không chứa cue phù hợp thường chỉ phát clip Talk; Talk đã được phân tích là có chuyển động tay rất nhỏ.
- Có nhiều nguồn cùng ghi `avatarClip`: `aiSpeaking`, `state`, `faceExpression`, transcript explain/context cues và task hoàn tất gesture. Ví dụ `applyAraEmotion(.speaking/.listening/.happy/.sad)` cũng trực tiếp đổi clip; các sự kiện này có thể ghi đè clip mà không có một bộ ưu tiên trung tâm.
- Khi `aiSpeaking` chuyển false, code gọi `cancelExplainGesture()` và `cancelEmotionGesture()` ngay lập tức; đây là hành vi có thể cắt ngắn gesture nếu trạng thái speaking kết thúc sớm.
- `AraAvatarView.swift` có một sway procedural riêng chỉ khi `currentClip == .idle`: góc sin ±3° quanh trục Z, tần số 0.3 Hz. Nó giải thích chính xác biên độ 3° nếu clip live bị trả về Idle; không phải cử chỉ tay của animation asset.
- `LiveVoice.swift` đặt `aiSpeaking = true` khi nhận audio chunk và false ở `turnComplete`/interrupted/teardown; `faceExpression` cũng được cập nhật độc lập từ audio/transcript. Không thay đổi file này trong bước điều tra.
- Kết luận: clip asset và playback đã được TEST xác nhận. Điểm yếu live-chat đã xác định là thiếu lịch cử chỉ hội thoại liên tục, heuristic cue thưa, và nhiều state writers có thể tranh quyền ghi clip. Không phải thiếu animation clip.
- Chưa sửa code. Trước triển khai cần thống nhất cách Ara cử chỉ khi nói: chỉ theo ngữ nghĩa câu trả lời hay kết hợp cử chỉ nền định kỳ có giới hạn; không nên tự chọn nhịp/tần suất gây vung tay liên tục. Khi triển khai, tập trung vào orchestration ở `CompanionChatView.swift`, giữ TEST UI, Ara loader/model và Gemini Live pipeline nguyên vẹn.


### Ara live-chat — sửa nhỏ lần 1: không cắt cử chỉ khi Gemini báo hết lượt
- Commit code: `9c5ed49246c1f204654a03dcec5fbbe5b4d46942`.
- Trước đây `onChange(aiSpeaking: false)` lập tức hủy `explainGestureTask` và `emotionGestureTask`, sau đó đặt clip về Listening/Idle. Điều này có thể cắt TalkExplain/Empathy/Laugh giữa chừng khi Gemini gửi `turnComplete`, dù animation clip riêng lẻ chạy đúng trong TEST.
- Sửa tối thiểu trong `CompanionChatView.swift`: nếu gesture task đang chạy, giữ clip hiện tại đến hết duration; khi TalkExplain hoàn tất, trả về Talk nếu AI còn nói, Listening nếu phiên vẫn live, hoặc Idle nếu phiên đã kết thúc.
- `applyAraEmotion` không được ghi đè clip khi gesture task đang hoạt động.
- Không sửa `LiveVoice.swift`, `AraAvatarView.swift`, TEST UI, asset, model, hay voice pipeline.
- Chưa build/chưa chạy trên iPhone. Cần Codemagic build và kiểm tra thực tế xem cử chỉ có giữ đủ thời lượng không; sau đó mới đánh giá tiếp lịch cử chỉ nền và cử chỉ theo ngữ nghĩa. Không tự thêm nhịp lặp định kỳ.


### Ara live-chat — sửa lần 2: không để tín hiệu bắt đầu nói ghi đè gesture
- Commit: `feb7f0a68d511746594a874617d2cee875c45a3b`.
- Phát hiện sau phản hồi người dùng: nhánh `aiSpeaking == true` vẫn gọi `cancelExplainGesture()` và luôn gán `avatarClip = .talk`. Điều này ghi đè TalkExplain và có thể làm tay hạ xuống sớm; lần sửa trước chỉ bảo vệ nhánh `aiSpeaking == false`.
- Đã bỏ lệnh hủy Explain khi bắt đầu nói. Chỉ chuyển sang Talk nếu không có Explain/Emotion gesture task đang chạy; nếu có thì giữ clip và ghi log chẩn đoán.
- Không thay đổi TEST UI, asset, Ara loader, LiveVoice/Gemini pipeline hoặc các tính năng chat khác.
- Chưa build/chưa kiểm chứng trên thiết bị. Người dùng cần chạy Codemagic và thử hội thoại để xác nhận.


## Ara — loại bỏ chuyển động lặp tự động trong live chat (2026-11-03)
- Theo yêu cầu người dùng, đã loại bỏ hoàn toàn procedural idle sway ±3° trong `AraAvatarView.swift`; xóa cả subscription cập nhật SceneEvents và state phase không còn dùng.
- Trong live chat, bỏ Wave tự động khi vừa kết nối; trạng thái live vào thẳng Listening.
- Bỏ các trigger gesture tự động từ transcript/emotion (TalkExplain, AraEmpathy, AraLaugh) cùng các task/generation/cue helper liên quan. Không còn các nguồn tự động giơ tay ngắn hoặc thay clip do faceExpression.
- Live chat chỉ còn chuyển trạng thái cơ bản: Talk khi AI phát tiếng, Listening khi đang nghe, Thinking khi kết nối, Idle khi phiên kết thúc. Các animation/action trong popup TEST vẫn giữ nguyên để người dùng chủ động kiểm tra.
- Không sửa asset Ara, loader/playback, Gemini Live/voice pipeline, Text Chat, Chibi Chat hoặc giao diện TEST/LOG.
- Chưa build/chưa kiểm chứng trên iPhone; người dùng tự chạy Codemagic. Mục tiêu là loại bỏ chuyển động tự động lặp/không cần thiết, không tuyên bố đã đạt độ tự nhiên cuối cùng.

## Ara — runtime rig TEST và tách Gemini Live (2026-11-03)
- HEAD sau thay đổi: `5dfc9431f11fc3be3aba1720c8c8d8abd881287f` trên `main`.
- `AraAvatarView.swift`: sau khi USDZ được nạp, duyệt hierarchy tìm các `ModelEntity` có `jointNames`; ghi log số model rig, số joint, số jointTransforms và danh sách joint thân trên (Head/Neck/Spine/Shoulders/Arms/ForeArms/Hands). Nếu RealityKit không expose rig, log rõ `No imported ModelEntity exposes jointNames`.
- `CompanionChatView.swift`: bỏ lệnh `liveManager.end()` khỏi lúc bắt đầu TEST. TEST không còn chủ động ngắt phiên Gemini Live; khi kết thúc TEST, avatar trở về Talk/Listening/Idle theo trạng thái Live hiện tại.
- Hai thay đổi đã commit trực tiếp lên `main`; không tạo branch, không chạy Codemagic/GitHub Actions.
- Đây mới là bước kiểm chứng runtime import joint, **chưa triển khai procedural upper-body movement và chưa build/test trên iPhone**. Không được tuyên bố joint import đã thành công chỉ từ code; cần đọc log thực tế sau build.
- Bước tiếp theo: dựa trên log jointNames/jointTransforms thực tế để thêm các chuyển động thử từng joint (đầu, vai, cánh tay, khuỷu, cổ tay), với baseline/reset rõ ràng và không đụng voice pipeline. Nếu không tìm thấy ModelEntity có rig hoặc transforms không khớp joint count, dừng và điều tra import thay vì dựng rig giả.


## Ara — sửa race khi khôi phục animation sau TEST (2026-11-04)
- Commit: `f926c832bc464f03d8ca8e2bb8b36cc197e2fa88` trên `main`.
- Trong `AraAvatarView.swift`, thay hai `.onChange` độc lập của `clip` và `repeatForTesting` bằng một `onChange` theo cặp trạng thái `AraPlaybackRequest` (Equatable). Mỗi lần cập nhật, loader nhận một cặp clip/repeat nhất quán, tránh gọi lại clip cũ khi hai state đổi cùng transaction lúc kết thúc TEST.
- Chỉ sửa `ChatAI/AraAvatarView.swift`; không đụng TEST UI, `CompanionChatView.swift`, Gemini Live, voice pipeline hoặc các phần chat khác.
- Chưa build/chưa kiểm chứng trên iPhone. Người dùng tự chạy Codemagic và thử lại TalkExplain → kết thúc TEST; log cần xác nhận không còn phát lại TalkExplain sau khi đã khôi phục Idle/Listening/Talk.


## Ara — chuyển sang chế độ tĩnh và xóa toàn bộ TEST (2026-11-04)
- Các mục kiểm thử 30 clip, 11 clip và điều phối animation ở phần lịch sử phía trên đã được đóng. Không khôi phục chúng.
- App hiện chỉ load USDZ, không parse timeline, không tạo AnimationView/AnimationResource, không gọi playAnimation và không giữ playback controller.
- LOG/Copy Log vẫn là công cụ chẩn đoán; nó không phải TEST animation. Các log [ARA STATIC] chỉ xác nhận trạng thái nạp model và việc không phát animation.
- Giai đoạn tiếp theo bị khóa cho đến khi người dùng xác nhận bằng mắt rằng Ara đứng yên trong IPA mới. Sau đó mới thiết kế hành động dùng trong hội thoại thực tế, không có test riêng.

## Build fix — Chat Voice helper methods (2026-11-04)
- Codemagic compile error: `addDiagnostic` and `handleLatestTranscript` were referenced by `CompanionChatView` but their definitions had been removed during Ara TEST cleanup.
- Restored `addDiagnostic` (timestamped, capped at 150 entries), `handleLatestTranscript`, and its text-only emotion classifier. These helpers update LOG/transcript/status labels only; they do not trigger Ara animation or actions.
- `AraAvatarView` remains a static loader; no TEST UI, clip playback, or action orchestration was restored.
- Fix commit: `4806ce1bcc493e3859ee0e25a62d5e73e41ee42e`.
- Not yet compiled or built; user must rerun Codemagic from `main` to verify.
- Follow-up correction: Swift string interpolation in the restored timestamped log line was verified and fixed in commit `633cb589737b4181a758092a50cbfc0d8e9829cd`.

## Ara — giai đoạn 2: chuẩn bị điều khiển hành động thân trên (2026-11-04)
- Người dùng đã duyệt phạm vi: cử chỉ thân trên trong hội thoại thật; không thử mặt/đầu/cổ/BlendShape; chuyển động phải mềm, tự nhiên; không tạo TEST UI riêng.
- Main trước bước này: `5ba3a2cdef404f0d33aa823e66b1d4a184200b9e`.
- Commit `0f35268c0659d7d2b897d4918065d95da7030990`: chỉ bổ sung chẩn đoán runtime rig trong `AraAvatarView.swift`. Khi USDZ nạp, tìm `ModelEntity` có `jointNames`, ghi số joint/transforms và index của 12 khớp thân trên (Spine, Spine1, Spine2, vai/cánh tay/cẳng tay/bàn tay trái/phải). Không phát animation, không thay đổi tư thế và không sửa voice pipeline.
- Project deployment target iOS 16.0. RealityKit `jointTransforms` có setter từ iOS 13 và `JointTransforms`/FromToByAnimation có từ iOS 15; có thể dùng API sẵn có để tạo chuyển động giới hạn theo danh sách joint mà không thêm dependency. Active animation có thể ghi đè jointTransforms, do đó không phát clip toàn thân song song với điều khiển khớp.
- Rig asset đã được phân tích trước đây có 69 joints; các index dự kiến: Spine 1, Spine1 2, Spine2 3; LeftShoulder/Arm/ForeArm/Hand 10–13; RightShoulder/Arm/ForeArm/Hand 34–37. Tuy nhiên runtime import chưa được xác minh trong IPA hiện tại.
- **Bước bắt buộc tiếp theo:** người dùng build IPA từ `main`, mở Chat Voice và gửi log có prefix `[ARA RIG]`. Nếu không có ModelEntity rig hoặc joint count không khớp, dừng để điều tra import; không đoán khớp/axis.
- Sau khi runtime rig xác nhận: triển khai thử cử chỉ thân trên đầu tiên (Wave) bằng các joint tay được xác nhận; sau đó mới thêm cử chỉ giải thích/mở tay và mapping vào sự kiện hội thoại. Listening giữ tư thế nghỉ. Không điều khiển Head/Neck/face/BlendShape; không sửa `LiveVoice.swift`, Gemini Live, chatbot/API, Text Chat hoặc Chibi Chat.
- Chưa có chuyển động mới trong commit này; chưa build/chưa kiểm chứng trên iPhone. Người dùng tự chạy Codemagic.




## Ara — dump đầy đủ runtime skeleton cho đợt test tổng hợp (2026-11-04)
- Main source commit: \`4fa69969227acf8f09222c6216e76e3624f9ad45\`.
- \`ChatAI/AraAvatarView.swift\`: sau khi tìm thấy rig, log tên khớp kèm index cho toàn bộ jointNames, chia nhóm tối đa 12 khớp mỗi dòng; vẫn ghi số joint/transforms và kết quả exact-name match.
- Chỉ bổ sung diagnostic; không thay đổi pose, không điều khiển joint, không phát animation, không thêm TEST UI, không sửa CompanionChatView hoặc LiveVoice/Gemini Live.
- Mục đích: lấy naming convention runtime chính xác trước khi thiết kế một lượt kiểm tra hành động thân trên. Chưa triển khai hành động vì cần xác nhận index/tên khớp từ IPA.
- Chưa build/chưa kiểm chứng trên iPhone. Người dùng build IPA từ main và gửi toàn bộ các dòng \`[ARA RIG]\`.

## Ara — fix Swift actor isolation trong rig diagnostics (2026-11-04)
- Codemagic báo lỗi tại hai dòng `self.onLog` bên trong nested function `inspectRig`: nested function bị xem là nonisolated nên không được truy cập trực tiếp thuộc tính MainActor-isolated.
- Fix tối thiểu trong `ChatAI/AraAvatarView.swift`: chụp closure `onLog` `let rigLog = self.onLog` trước khi khai báo/duyệt rig; nested function chỉ gọi closure đã capture, không truy cập `self.onLog`.
- Không đổi logic duyệt joint, nạp USDZ, chuyển động, UI, Gemini Live hoặc voice pipeline.
- Fix commit: `dcaa4151f3160fb6a29690c4c40ab4c49cc14b8d` trên `main`.
- Chưa chạy Xcode/Codemagic; cần build IPA lại để xác minh compiler. Nếu còn lỗi, xử lý theo lỗi đầu tiên trong log mới.


## Ara — xác nhận skeleton và dump tư thế gốc (2026-11-05)
- IPA do người dùng build xác nhận runtime rig: 1 ModelEntity tên `Hips`, `jointNames=69`, `jointTransforms=69`; đủ skeleton để tiếp tục giai đoạn 2.
- Mapping đã xác nhận từ log: Spine/Spine1/Spine2 = 1–3; LeftShoulder/LeftArm/LeftForeArm/LeftHand = 10–13; RightShoulder/RightArm/RightForeArm/RightHand = 34–37.
- Joint name do RealityKit trả về là full path (ví dụ `Hips/Spine/Spine1/Spine2/LeftShoulder`), vì vậy phép so sánh exact-name cũ với leaf name làm log báo nhầm `none`. Đã sửa phần diagnostic để so sánh thành phần cuối của path.
- Source commit mới: `f0c5b5c3ff51514d70206c73587414e3f58e5efe` — `ChatAI/AraAvatarView.swift` chỉ sửa log mapping và bổ sung dump tư thế gốc (translation/quaternion/scale) cho 11 joints: Spine 1–3 và hai tay 10–13, 34–37.
- Không có điều khiển joint, không thay đổi tư thế, không phát animation, không thêm TEST UI; không sửa CompanionChatView, LiveVoice/Gemini Live hoặc voice pipeline.
- Cần người dùng build IPA từ `main` và gửi các dòng `[ARA RIG] upper-body matches` cùng `[ARA RIG] rest[` để xác định local axes/pose trước khi triển khai Wave. Chưa build Xcode/Codemagic hoặc kiểm chứng chuyển động.
