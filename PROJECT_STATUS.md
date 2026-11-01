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
- Tiếp tục phát triển Ara avatar 3D trong màn hình Chat Voice bằng RealityKit.
- Ara đã tải và phát animation trên iPhone; log thực tế xác nhận luồng voice chuyển trạng thái connecting/live, nhận tin nhắn, bật/tắt speaking và chuyển clip Idle/Thinking/Wave/Listening/Talk.
- Log xác nhận asset và playback được khởi tạo, không tự chứng minh chất lượng cử chỉ bằng mắt hoặc mọi clip đã tự nhiên.
- Phong cách mục tiêu: tự nhiên, nhẹ nhàng, nữ tính; tránh động tác phóng đại, lặp gật đầu hoặc nhìn quanh.
- Không thay chatbot hoặc voice pipeline để phát triển animation. Không lấy `aiSpeaking` đơn thuần làm căn cứ duy nhất chọn cảm xúc/gesture.
- Ưu tiên: bộ cử chỉ cơ thể và biểu cảm có thể kiểm thử rõ ràng; sau đó hoàn thiện lựa chọn theo ngữ cảnh hội thoại; lip-sync/viseme tiếp tục là giai đoạn riêng.

## Nguyên tắc dữ liệu Ara — nghiên cứu/gom một lần, tái sử dụng lâu dài
- Không chạy GitHub Action cho từng cử chỉ nhỏ hoặc mỗi lần thay đổi logic Swift. Trước khi tạo asset tiếp theo phải nghiên cứu và chốt danh mục cử chỉ cần test cho cả roadmap.
- Mục tiêu là một lần tạo **bộ asset Ara hoàn chỉnh có thể tái sử dụng**: master USDZ/timeline chứa các clip đã chọn và xác minh; đồng thời Release phải lưu GLB nguồn, research dataset, manifest, diagnostics, provenance và SHA256.
- Không ép ghép tất cả animation nếu rig channels, interpolation, skeleton hoặc conversion không tương thích. Trước tiên phân loại 75 clip theo rig/channels, chất lượng, thời lượng, nhóm hành vi; nếu cần tách nhóm USDZ vì giới hạn kỹ thuật thì ghi rõ lý do và vẫn tạo toàn bộ trong cùng một đợt chuẩn bị.
- Release phải có version/tag bất biến theo bộ dữ liệu; không ghi đè một bản đã phát hành. Codemagic chỉ lấy đúng asset/release đã được xác định, không tự dùng artifact mới nhất không rõ phiên bản.
- Khi cần nghiên cứu/chọn lại clip đã có trong GLB và research dataset của Release, lấy dữ liệu đó ra phân tích; không chạy lại bước sinh GLB từ upstream. Chỉ cần tạo lại/chuyển USDZ khi thực sự bổ sung hoặc thay đổi bộ asset đóng gói, và gom các thay đổi vào một đợt.
- Thay đổi Swift như trigger clip, thời điểm chuyển trạng thái, mapping ngữ cảnh hoặc UI log không cần chạy GitHub Action tạo USDZ. Chỉ cần build Codemagic khi cần kiểm thử thay đổi app.
- Không chạy Action/Codemagic tự động; chỉ chuẩn bị thay đổi và chờ user chủ động chạy sau khi duyệt.

## Danh mục cử chỉ Ara cần nghiên cứu và kiểm thử
Mục tiêu là có đủ clip để thử hành vi hội thoại thực tế, không chỉ 8 clip demo hiện tại. Đây là danh mục yêu cầu nghiên cứu; chưa khẳng định mọi động tác đều có sẵn trong 75 clip nguồn.

1. **Nền và tư thế:** Idle tự nhiên; nhịp thở/nhún vai rất nhẹ; chuyển trọng tâm; sway thân nhẹ; trở về tư thế nghỉ.
2. **Lắng nghe:** Listening attentive; gật đầu đồng ý một lần; nghiêng đầu nhẹ; nhìn người đối thoại/camera; phản hồi xác nhận.
3. **Suy nghĩ:** Thinking/pause; nhớ lại; phân vân; tò mò; chuyển từ suy nghĩ về trạng thái nói.
4. **Nói và giải thích:** Talk trung tính; giải thích bằng lòng bàn tay mở; nhấn ý bằng một tay; trình bày/mời xem; chỉ hướng hoặc chỉ vật thể khi có ngữ cảnh; đếm ý 1–2–3 nếu có clip phù hợp.
5. **Cảm xúc:** Smile; laugh; empathy/quan tâm; concern/buồn nhẹ; surprise; confusion; reassurance/động viên. Cần phân biệt biểu cảm mặt với cử chỉ thân thể.
6. **Chuyển tiếp xã giao:** Greeting/wave; farewell; chuyển clip mượt và không giật về Idle/Talk.
7. **Phối hợp nâng cao:** Cử chỉ không lấn át lời nói; không lặp vô hạn động tác one-shot; ưu tiên tay trái/phải có chủ đích; tránh xuyên thân/mặt và tư thế bàn tay lỗi; tương thích về sau với facial expression và viseme.

## Kế hoạch kiểm thử
- Test riêng từng clip: tên/ID, thời lượng, loop hay one-shot, bộ phận chuyển động, biên độ, điểm bắt đầu/kết thúc, tư thế nghỉ sau clip.
- Test chuyển tiếp: Idle → Listening → Thinking → Talk; Talk → TalkExplain/gesture → Talk; Talk → Laugh/Empathy → Talk/Idle; Greeting/Farewell → Idle.
- Test tình huống hội thoại: câu trả lời ngắn/dài, giải thích nhiều ý, chờ người dùng, câu vui, câu đồng cảm, không có cue cảm xúc.
- Đánh giá trên iPhone thật: độ tự nhiên, độ rõ khi nhìn, độ lặp, độ trễ, giật/chồng animation, lỗi rig/bàn tay và ảnh hưởng hiệu năng.
- Ghi log có chọn lọc: clip được chọn, lý do/cue, start/end, fallback; không tạo log khổng lồ.

## Pipeline Ara hiện tại — Release v4 đã phát hành
- Workflow tạo asset: `.github/workflows/generate-ara-usdz.yml` trên `main`, chạy thủ công. Upstream `olatunde85/3d-gen` được pin tại `e26cdef1464a0babf23bb0235b5f05930301ee25`.
- Release `ara-avatar-v4` là bộ tài nguyên chuẩn hiện tại. Release chứa GLB nguồn, USDZ RealityKit, timeline, research dataset đầy đủ, conversion log, diagnostics và checksum. Dữ liệu được lưu lâu dài trên GitHub Releases; khi cần phân tích/test lại, lấy trực tiếp từ release này, không chạy lại Action để lấy dữ liệu cũ. Codemagic đã build thành công sau khi pipeline được sửa; luồng lấy USDZ/timeline đã trả về đúng bộ dữ liệu Ara v4.
- Nguồn có **75 animation clips, 69 joints, 34 morph targets**. Đã kiểm tra toàn bộ dataset: mỗi clip đều có 71 channels (69 rotation, 1 Hips translation, 1 blendshape weights), cùng target signature/output width, tất cả LINEAR; không tìm thấy clip nào lệch rig channels hoặc interpolation. Tổng thời lượng 75 clip khoảng 138.59 giây.
- 75 clip được phân loại thành: conversational/emotes; locomotion; jump/fall; combat/reactions; turns; sitting/lying; weapons; vehicles. Các nhóm locomotion/combat/weapons/vehicles/sitting/lying không phù hợp avatar trợ lý đứng trò chuyện hiện tại nên giữ trong research dataset, không đưa vào runtime pack lần này.
- **Bộ conversation test được chọn: 11 clips, khoảng 32.57 giây**:
  - 8 clip nền hiện tại: Idle, Wave, Talk, TalkExplain, AraListening, AraThinking, AraEmpathy, AraLaugh.
  - 3 clip bổ sung: Cheer, Laugh, Cry. Đây là bộ có ích cho chào hỏi, giải thích, lắng nghe, suy nghĩ, đồng cảm, cười, vui mừng và phản ứng buồn; Cry chỉ để test thủ công, chưa tự động kích hoạt.
- Đánh giá từ keyframes GLB:
  - `TalkExplain` có chuyển động tay phải rõ: RightArm khoảng 52.9°, RightForeArm 39.7°, RightHand 31.1° so với đầu clip; giữ làm cử chỉ giải thích.
  - `Wave` đưa tay phải lên vị trí chào; pose khác Talk khoảng 103° ở RightArm và 95° ở RightForeArm; dùng one-shot.
  - `Cheer` nâng cả hai tay mạnh, khoảng 100° ở hai cánh tay/cẳng tay; chỉ dùng cho vui mừng rõ, không tự kích hoạt khi trò chuyện thường.
  - `Laugh` có nhún thân, đầu ngửa nhẹ, tay phải đặt bụng và morph cười (mouthSmile, jawOpen, eyeSquint); là ứng viên cười rõ hơn.
  - `Cry` có biểu cảm buồn và chuyển động thân/tay rất mạnh; chỉ thử thủ công, không map tự động vào trạng thái buồn.
  - `AraListening`, `AraThinking`, `AraEmpathy` chủ yếu là vi chuyển động đầu/cổ/thân trên (khoảng 1–5°), không có facial morph đặc trưng ngoài chớp mắt; giữ vai trò trạng thái nền nhẹ, không xem là cử chỉ tay rõ.
  - `AraLaugh` cũng khá nhẹ (đầu/mắt), không có morph cười rõ. Hiện logic tự động vẫn gọi `AraLaugh`; sẽ so sánh với clip `Laugh` trên iPhone trước khi đổi mapping.
- Các cử chỉ chưa có clip chuyên biệt trong nguồn: gật đầu đồng ý một lần, đưa tay lên ngực để trấn an/đồng cảm, chỉ hướng và đếm ý. Không tự đoán IK target để nhồi vào lần build này; chỉ bổ sung procedural clip sau khi test bộ hiện có và xác định rõ động tác còn thiếu.
- App enum/test panel đã có Cheer, Laugh, Cry để thử thủ công. `AraAvatarLoader` vẫn yêu cầu 8 clip nền; 3 clip bổ sung là optional để không làm hỏng load nếu asset thiếu.
- Hip sway đã được chỉnh `AMPLITUDE_DEGREES = 5.0`, `FREQUENCY_HZ = 0.8`, 30 FPS; chỉ bake vào Talk và AraListening. Giữ nguyên, không thêm runtime sway chồng lên.
- Workflow phát hành theo tag bất biến `ara-avatar-v4`, `overwrite_files: false`; không ghi đè release đã phát hành. Release notes mô tả timeline hội thoại tối đa 11 clip, gồm Cheer, Laugh và Cry tùy chọn.
- GitHub Action run **#15** (`41266922525`) hoàn tất `success` ngày 2026-11-01 trên `main`, commit `2af8ccd9385d06c1cdb7296fbcb51c8bf925535c`. Release `ara-avatar-v4` được publish thành công. Codemagic đã build IPA thành công từ pipeline lấy dữ liệu Ara v4 sau khi sửa; bộ clip vẫn cần kiểm thử trực quan trên iPhone.

## Trạng thái kỹ thuật đã xác minh
- Runtime log: Ara USDZ tải từ app bundle thành công (~25.5 MB); RealityKit import 1 global scene animation; app tạo 8 AnimationViews từ timeline.
- Log ghi nhận luồng voice connecting → live, nhận user/assistant messages, speaking true → false và chuyển clip. Đây là xác nhận tích hợp playback/voice state ở mức log.
- Playback đã thấy trong log: Idle → AraThinking → Wave → AraListening → Talk → Idle.
- `TalkExplain skipped: no explanation cue` trong lần test ngắn; đây là thiếu cue kích hoạt ở tình huống test, không phải bằng chứng clip bị lỗi.
- Người dùng quan sát Ara hơi lắc nhẹ khi nói và đôi lúc giơ tay phải rồi hạ nhanh; cần thêm clip/gesture có khác biệt rõ để đánh giá trực quan.
- Không kết luận chuyển động tự nhiên/chất lượng chỉ từ log; cần video/quan sát iPhone thật và kiểm thử từng clip.

## Việc tiếp theo
1. Codemagic đã tải được đúng bộ Ara USDZ/timeline và build IPA thành công sau khi sửa pipeline (xem mục xác minh build bên dưới).
2. Test từng clip trên iPhone thật: đặc biệt so sánh AraLaugh với Laugh; Cheer và Cry chỉ test thủ công; kiểm tra chuyển tiếp về Talk/Idle, độ tự nhiên và hiện tượng giật/chồng animation.
3. Sau test mới quyết định mapping tự động theo ngữ cảnh, thêm gesture procedural nếu còn thiếu; lip-sync/viseme vẫn là giai đoạn riêng.
4. Nếu cần nghiên cứu lại tài nguyên hiện có, dùng GLB/research bundle/diagnostics từ Release v4. Chỉ tạo release tài nguyên phiên bản mới khi thực sự thay đổi hoặc bổ sung asset; cập nhật PROJECT_STATUS.md sau khi release mới được xác minh.

## Build và xác minh
- Codemagic workflow chính: `ios-unsigned`; assistant không dispatch Codemagic trực tiếp.
- Build simulator chỉ xác nhận compile/package, không thay thế kiểm thử trên iPhone thật.
- Không build IPA từ asset mới trước khi review kết quả USDZ post-conversion.

## Xác minh Action v4 và quy tắc tái sử dụng tài nguyên — 2026-11-01
- Action run: **#15**, ID `41266922525`, trạng thái `completed / success`, branch `main`, commit đầu vào `2af8ccd9385d06c1cdb7296fbcb51c8bf925535c`.
- Release: [`ara-avatar-v4`](https://github.com/tpios-tp2586/Chat-ai-tpios/releases/tag/ara-avatar-v4), tên `Ara Avatar and Research Data v4`, publish `2026-11-01T02:56:14Z`.
- Release assets đã xác minh metadata:
  - `Ara-Avatar.usdz` — 25,500,329 bytes; SHA256 `442e51bf45e4a6fcd2d9d322597b635531e0059be065be35b94f3320ce6ee124`.
  - `Athletic_woman.glb` — 17,534,748 bytes; SHA256 `5e922c88cb665593ab4c47973b6368df0205996f24290654a83d38cb47dd2e1e`.
  - `ara-research-data.json.gz` — 3,235,099 bytes; SHA256 `144bc52b1e9d3a33fc71e28e2ba03c79f4d2e65d193bec5371abf71af9ef95ed`.
  - `animation-timeline.json` — 1,608 bytes; SHA256 `23abe4d940a022ade19276740296e348900dffea4996f95f57f156dbb0f3e0fe`.
  - Diagnostics/report files: `animation-diagnostics.txt`, `conversion-log.txt`, `texture-diagnostics.txt`, `usdz-animation-diagnostics.txt`, `usdz-report.txt`, `verification-report.txt`; checksum manifest `SHA256SUMS.txt`.
- Workflow artifacts cũng đã được tạo, chưa hết hạn: `ara-avatar-research-bundle` ID `13067582323` (~13.25 MB) và `ara-avatar-glb` ID `13067517492` (~8.15 MB). Release là nguồn tham chiếu lâu dài ưu tiên; workflow artifacts là bản phụ để tải khi cần.
- **Quy tắc từ nay:** dùng dữ liệu Release v4 để nghiên cứu, kiểm tra rig/animation, chọn clip và chuẩn bị test. Không chạy lại Action chỉ để lấy lại dữ liệu hoặc đổi logic Swift. Nếu thay đổi/bổ sung tài nguyên (GLB/clip/timeline/USDZ/texture), tạo release phiên bản mới, không ghi đè v4; sau khi xác minh mới cập nhật status.
- Codemagic tải trực tiếp `Ara-Avatar.usdz`, `animation-timeline.json` và `ara-asset-pipeline.txt` từ Release `ara-avatar-v4` (không phụ thuộc workflow artifact có thời hạn). Trước khi tải, Codemagic xác nhận tag `ara-avatar-v4` trỏ đúng commit SHA của lần Action thành công mới nhất. Codemagic vẫn chỉ xuất IPA, không ZIP. Guard cho phép commit chỉ thay đổi `PROJECT_STATUS.md` và `codemagic.yaml` sau Action; nếu có thay đổi file app, script animation hoặc workflow tạo asset sau SHA của Action, Codemagic sẽ từ chối release cũ và yêu cầu Action/release tài nguyên mới.
- **Chưa xác minh:** nội dung timeline/diagnostics bên trong từng asset chưa được đọc lại độc lập từ release binary trong phiên này; chất lượng chuyển động, texture khi render và chuyển tiếp clip phải kiểm tra trên iPhone. Không coi Action success là bằng chứng chuyển động tự nhiên hoặc app runtime thành công.


## Codemagic 403 khi tải Ara v4 — 2026-11-01
- Nguyên nhân kỹ thuật đã khoanh vùng: commit `293d2692b18b52b02d47cd6e4d4310c9fb051d3d` đưa thêm yêu cầu gọi API `/commits/main` để kiểm tra SHA. Đây là endpoint cần quyền đọc Contents; luồng cũ chủ yếu dùng Actions API. Sau đó chuyển nguồn tải sang GitHub Release cũng làm phát sinh thêm các endpoint cần Contents: Read.
- User xác nhận không thay token hoặc cấu hình Codemagic; token là loại không thời hạn. Vì vậy không kết luận token hết hạn và không yêu cầu tạo token mới.
- Đã sửa `codemagic.yaml`: dùng commit checkout sẵn trong Codemagic để kiểm tra ancestry và các file thay đổi sau Ara workflow run, bỏ API call lấy `main` SHA và API compare. Chỉ cho phép thay đổi `PROJECT_STATUS.md` và `codemagic.yaml` sau asset run.
- Pipeline ưu tiên tải tài nguyên từ Release `ara-avatar-v4` khi token có quyền Contents. Nếu Release/Contents API bị từ chối, tự động fallback sang artifact `ara-avatar-research-bundle` đúng workflow run ID; không lấy artifact của run khác và không dùng artifact đã hết hạn. Fallback chỉ cần Actions: Read.
- Đã xác minh artifact đúng run #15 / ID `41266922525` tồn tại, chưa hết hạn: artifact ID `13067582323`, dự kiến hết hạn `2027-01-30T02:52:28Z`. Release v4 vẫn là nguồn ưu tiên lâu dài.
- Commit sửa pipeline: `1272e4a71b6f93d3597e96542d1a4bf5651cb396`. Không chạy GitHub Action hoặc Codemagic trong lúc sửa; user đã tự chạy workflow `ios-unsigned` và xác nhận build thành công (chi tiết ở mục xác minh build bên dưới).

## Codemagic build xác nhận lấy đúng Ara USDZ — 2026-11-01
- User xác nhận workflow `ios-unsigned` trên Codemagic **build thành công** sau commit sửa pipeline `1272e4a71b6f93d3597e96542d1a4bf5651cb396`.
- Pipeline hiện chọn dữ liệu theo đúng Ara workflow run #15 / ID `41266922525`, commit nguồn `2af8ccd9385d06c1cdb7296fbcb51c8bf925535c`: ưu tiên Release bất biến `ara-avatar-v4`; nếu Release API/asset download không truy cập được thì chỉ fallback sang artifact `ara-avatar-research-bundle` thuộc đúng run ID này.
- Build thành công xác nhận pipeline đã lấy được bộ đầu vào Ara hợp lệ (`Ara-Avatar.usdz`, `animation-timeline.json`, marker `hips_sway_baked=false`), qua bước bake/validate OpenUSD và hoàn tất build IPA.
- Chưa có log chi tiết của lần build trong phiên này nên **chưa xác định được lần chạy thành công thực tế dùng nhánh tải Release hay nhánh fallback Actions artifact**. Cả hai đều được ràng buộc về đúng bộ Ara v4/run #15; không dùng artifact mới nhất tùy tiện.
- Không cần thay token hoặc tạo GitHub Action run mới cho lần build này. Assistant không chạy Codemagic; build do user chủ động thực hiện.
- Bước kế tiếp chuyển sang kiểm thử trực quan 11 clip Ara trên iPhone; ưu tiên so sánh `AraLaugh` và `Laugh`, thử thủ công `Cheer`/`Cry`, kiểm tra chuyển tiếp và độ tự nhiên.

## Quy trình test cử chỉ trực quan trên iPhone — đã thống nhất
- Khi cần test hoặc đánh giá lại animation Ara, tạm hiển thị một cụm nút test ngay trên màn hình Chat Voice, bố trí xung quanh nhân vật Ara để dễ quan sát và thao tác.
- Mỗi nút gọi trực tiếp đúng clip tương ứng (ví dụ Wave, Talk, TalkExplain, AraListening, AraThinking, AraEmpathy, AraLaugh, Laugh, Cheer, Cry). Không giả định clip đã được tích hợp tự động vào hội thoại chỉ vì nút test chạy được.
- Khi user bấm nút, Ara thực hiện trọn hành động với thời lượng đủ lâu để quan sát rõ toàn bộ động tác; không cắt clip quá sớm. Với clip one-shot, giữ pose cuối một khoảng ngắn nếu cần, sau đó chuyển mượt về Idle. Clip loop chỉ loop trong thời gian test có kiểm soát.
- Không để thao tác test làm animation trước bị cắt đột ngột hoặc tạo nhiều animation chồng nhau. Khi bấm clip khác, dừng/chuyển clip trước có kiểm soát và ghi nhận rõ clip thực tế được phát.
- Đánh giá trực tiếp trên iPhone: động tác tay/chân/thân/đầu, biên độ, độ tự nhiên, độ giật, thời lượng, pose kết thúc, chuyển tiếp về Idle và lỗi rig. Ghi nhận clip đạt / cần chỉnh / không phù hợp; không test lại clip đã được xác nhận nếu không có thay đổi liên quan.
- Sau khi clip được xác nhận bằng mắt, mới quyết định giữ/bỏ và tích hợp trigger theo ngữ cảnh hội thoại. Sau đó kiểm thử hội thoại thật để xác nhận hệ thống tự chọn đúng cử chỉ; nút test không phải bằng chứng của trigger tự động.
- Cụm nút và logic test chỉ là công cụ phát triển tạm thời. Khi hoàn tất chọn clip, mapping hội thoại và kiểm thử thực tế, phải gỡ toàn bộ UI test cùng code/test hooks không còn cần khỏi màn hình Chat Voice; không để xuất hiện trong bản production.
- Giữ nguyên phạm vi an toàn: không sửa Text Chat, Chibi Chat, chatbot/API, chat history hoặc voice pipeline khi chỉ bổ sung công cụ test animation Ara. Ưu tiên thay đổi tối thiểu; không chạy Action/Codemagic tự động.


## Ara gesture test UI implementation — 2026-11-01
- Đã thay sheet test cũ bằng cụm nút test overlay trực tiếp quanh vùng hiển thị Ara trong Chat Voice; có 2 hàng cuộn ngang để thao tác trên iPhone.
- Các nút hiện có: Wave, Talk, Explain/TalkExplain, Listen/AraListening, Thinking/AraThinking, Empathy/AraEmpathy, AraLaugh, Laugh, Cheer, Cry và Idle.
- Bật chế độ test sẽ dừng phiên voice đang chạy để state hội thoại không ghi đè clip. Trong chế độ test, các callback voice/transcript/emotion không được phép thay clip test.
- Mỗi clip test được loop trong cửa sổ 7 giây để quan sát rõ; hết thời gian tự trở về Idle. Bấm clip khác sẽ hủy timer cũ, dừng playback trước và chạy clip mới; có log Started/Finished.
- Chỉ thay đổi CompanionChatView.swift và AraAvatarView.swift; không thay đổi Text Chat, Chibi Chat, API/history hoặc voice pipeline. Không thêm dependency.
- Commit UI: 783108e40bb24b2c32ca4039f2c58e0d0a608543; commit playback/test-loop: 3944f9c030ede52431a864495a116d8d66b6a493; commit chặn voice ghi đè test: 49a70cd09bee055850a55cd970c44483b6157f39.
- Kiểm tra tĩnh sau cập nhật: xác nhận sheet test cũ đã được gỡ, đủ 11 nút clip, cờ test được truyền tới loader, clip test loop và tự về Idle sau 7 giây; các guard ngăn voice/transcript ghi đè chế độ test.
- Chưa xác minh bằng Xcode/Codemagic hoặc iPhone thật trong phiên này. Cần user chạy workflow ios-unsigned trên Codemagic và kiểm tra bố cục overlay, từng nút, thời lượng loop 7 giây, dừng/chuyển clip và trở về Idle. Assistant không chạy Codemagic.


## Codemagic guard compatibility for Ara gesture test — 2026-11-01
- Build bị dừng tại assertion `Non-documentation changes since Ara asset run` vì guard cũ chỉ cho phép PROJECT_STATUS.md và codemagic.yaml, trong khi thay đổi test UI có chủ đích nằm ở CompanionChatView.swift và AraAvatarView.swift.
- Đã sửa allowlist trong codemagic.yaml để chỉ cho phép thêm đúng hai file Swift test Ara này; các file nguồn/tài nguyên khác vẫn bị chặn như trước. Không bỏ guard ancestry hoặc kiểm tra thay đổi.
- Commit: 4200b5d6774e8fe82b01bd818d1719cfb223ff8e.
- Chưa chạy lại Codemagic; cần user chạy workflow ios-unsigned để xác minh bước bake USDZ và build IPA tiếp tục thành công. Assistant không tự chạy build.


## Điều chỉnh bố cục nút test Ara quanh nhân vật — 2026-11-01
- User nhắc lại yêu cầu đã chốt: các nút test phải bố trí xung quanh nhân vật Ara, không xếp thành hai hàng ngang phủ lên vùng avatar.
- Đã đổi overlay trong `ChatAI/CompanionChatView.swift`: 6 nút thành cột dọc bên trái, 5 nút thành cột dọc bên phải; thanh trạng thái test và nút Xong ở phía trên. Thu gọn chip để dành vùng trung tâm cho Ara.
- Giữ nguyên 11 clip, hành vi test/loop 7 giây, log và các guard voice. Không sửa Text Chat, Chibi Chat, API/history hoặc voice pipeline.
- Commit bố cục: `16d29cbb3af77a010390bbe8c8cc71b489ee370a`.
- Chưa có Xcode/Codemagic/iPhone verification cho bố cục mới; cần build IPA và xem trực tiếp trên iPhone để đánh giá độ cân đối, tránh che tay/thân Ara.
