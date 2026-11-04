# ChatAI — Project Checkpoint

## Repository
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trực tiếp trên `main`; tuyệt đối không tạo hoặc chuyển branch.
- Code giao diện Ara gần nhất: `61f55bc9636bb879fc5a9708f154dc7f969a4367` — popup TEST bỏ chữ `Test`, chỉ hiện tên nhóm (`T. Chuyện`/`Y. Cầu`), thu gọn hàng tiêu đề và giữ danh sách một cột dọc.
- Checkpoint trước lần cập nhật này: `db9591b1678918b80ba082dc78f0cb84f10831f1`.
- Lịch sử thay đổi xem trong Git commits/diffs.

## Quy tắc bắt buộc
- Trước khi sửa code: kiểm tra HEAD và đọc code thực tế đúng phạm vi; không đoán.
- Ưu tiên thay đổi tối thiểu, không thêm dependency nếu không cần (Ponytail).
- Bảo vệ chatbot/API, chat history, voice pipeline, Text Chat và Chibi Chat. Không sửa các phần này khi làm Ara.
- Không tạo branch; không tự chạy/dispatch GitHub Actions hoặc Codemagic. Người dùng tự chạy build thủ công.
- Codemagic chỉ xuất IPA; không thêm ZIP artifact ngoài yêu cầu.
- Người dùng thao tác chủ yếu trên iPhone; hướng dẫn ngắn gọn, rõ ràng.
- Không sửa đi sửa lại từng chi tiết nhỏ. Phải hiểu và chốt yêu cầu, kiểm tra toàn bộ code liên quan, gom thay đổi thành một lần hợp lý, rà diff trước khi commit.

## Hướng hiện tại
- Tiếp tục Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Không quay lại phương án 8 ảnh biểu cảm thay cho avatar 3D.
- Ara đã load và phát animation trên iPhone ở các lần build trước; cần đánh giá bằng quan sát thực tế, không chỉ dựa vào log.
- Không thay đổi chatbot hoặc voice pipeline để xử lý animation/UI test.

## Ara — giao diện TEST (tạm chốt)
- Trên thanh công cụ Chat Voice, giữ nút LOG và nút TEST cùng kích thước 42×42 pt.
- Chức năng sáng/tối riêng của Chat Voice đã được xóa: state `nightMode`, nút đổi nền và lớp phủ đen. Vẫn giữ Theme chung của ứng dụng qua `activeTheme`.
- Icon TEST mở popup SwiftUI tự thiết kế; không dùng native Menu hoặc sheet cho phần test.
- Popup không hiển thị chữ `Test`; màn hình chọn nhóm chỉ có hai ô `T. Chuyện` và `Y. Cầu` cùng nút đóng. Khi vào nhóm, tiêu đề chỉ hiện tên nhóm, nút quay lại chỉ dùng icon mũi tên.
- Popup tự co theo nội dung; hàng tiêu đề gọn. Khi mở nhóm, các hành động xếp thành một cột dọc; mỗi ô 40×40 pt, danh sách dài có thể cuộn.
- Chọn hành động chạy clip tương ứng nhưng giữ popup và nhóm đang chọn mở để tiếp tục test; test mode chỉ bật nội bộ trong lúc chạy và tự kết thúc về Idle.
- Giữ nguyên 26 clip/action, callback, thời lượng animation, chuỗi Jump và log chẩn đoán; giữ nút sao chép log.
- Người dùng đánh giá phần TEST hiện tại là tạm ổn. Không tiếp tục chỉnh sửa giao diện/chức năng TEST nếu chưa có yêu cầu mới.
- **Đã loại bỏ hoàn toàn khỏi tool** chức năng kéo di chuyển, zoom/thu phóng và thu gọn/resize khung test vì hoạt động không ổn. Không khôi phục, không tối ưu lại, không đưa các chức năng này thành đầu việc tiếp theo.

## Trạng thái và việc tiếp theo
- Phần TEST tạm chốt; không tự ý chỉnh thêm.
- Đã xác nhận lộ trình Ara toàn thân: giai đoạn 1 thử nghiệm khung hình/chuyển động thân trên (đầu, vai, ngực, hai tay); khi đạt yêu cầu mới mở rộng giai đoạn 2 xuống hông, chân, bàn chân; giai đoạn 3 hoàn thiện chuyển động toàn thân. Thân trên chỉ là bước kiểm chứng, không phải phạm vi sản phẩm cuối.
- Không loại bỏ rig hoặc animation chân khỏi asset trong giai đoạn 1; giữ nguyên một model Ara hiện tại để tiếp tục mở rộng.
- Giữ iOS 16.0, không sửa Gemini Live/voice pipeline, chatbot/API, Text Chat hoặc Chibi Chat. Giữ nguyên giao diện TEST và LOG/Copy Log.
- Đã cập nhật `AraAvatarView.swift`: khung hình thử nghiệm căn tâm theo vùng thân trên (dịch tâm lên 0,27 chiều cao toàn model, tương ứng vùng tâm khoảng 77% chiều cao theo phân tích skin-weight GLB). Giữ nguyên tỷ lệ scale hiện tại, toàn bộ mesh/skeleton và animation thân dưới; không cắt model. Thay đổi mới ở mức mã nguồn, chưa được build hoặc kiểm tra trên iPhone.
- Bước tiếp theo: người dùng chạy Codemagic và kiểm tra khung hình + chuyển động thân trên; nếu đạt mới mở rộng khung hình xuống thân dưới. Nếu lệch, dùng log/ảnh thực tế để hiệu chỉnh, không đoán thêm offset.
- Trạng thái build Codemagic mới nhất chưa được xác nhận trong checkpoint này; không tự chạy build.
- Nếu người dùng báo lỗi build/UI, yêu cầu log hoặc ảnh thực tế phù hợp rồi mới điều tra và sửa.

## Tiếp tục ở khung chat mới
Đọc checkpoint này và kiểm tra HEAD trên `main` trước khi làm việc. Phần TEST Ara đang tạm chốt. Tuyệt đối không khôi phục chức năng kéo di chuyển, zoom/thu phóng hoặc thu gọn/resize khung test đã bị loại bỏ. Chưa có đầu việc tiếp theo được xác nhận; hỏi người dùng trước khi bắt đầu. Không tạo branch và không tự chạy Codemagic/GitHub Actions.

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
