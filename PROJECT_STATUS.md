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
6. **Chuyển tiếp xã giao:** Greeting/wave; farewell; chuyển clip mượt và không giật về Idle.
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
1. Tiếp tục kiểm thử trực quan các clip còn lại trên iPhone, ưu tiên Laugh, Cheer và Cry; phân biệt rõ chuyển động toàn thân với vi chuyển động đầu/mặt.
2. Chốt danh sách clip thực sự khác biệt và mapping tự động theo ngữ cảnh; chỉ bổ sung gesture procedural nếu test cho thấy thiếu động tác cụ thể.
3. Lip-sync/viseme vẫn là giai đoạn riêng.
4. Nếu cần nghiên cứu lại tài nguyên hiện có, dùng GLB/research bundle/diagnostics từ Release v4. Chỉ tạo release tài nguyên phiên bản mới khi thực sự thay đổi hoặc bổ sung asset; cập nhật PROJECT_STATUS.md sau khi release mới được xác minh.

## Build và xác minh
- Codemagic workflow chính: `ios-unsigned`; assistant không dispatch Codemagic trực tiếp.
- Build simulator chỉ xác nhận compile/package, không thay thế kiểm thử trên iPhone thật.
- Không build IPA từ asset mới trước khi review kết quả USDZ post-conversion.

## Quy trình test cử chỉ trực quan trên iPhone — đã thống nhất
- Khi cần test hoặc đánh giá lại animation Ara, tạm hiển thị cụm nút test ngay trên màn hình Chat Voice, bố trí xung quanh nhân vật Ara.
- Mỗi nút gọi trực tiếp đúng clip tương ứng. Không giả định clip đã được tích hợp tự động vào hội thoại chỉ vì nút test chạy được.
- Clip test loop trong thời gian có kiểm soát để quan sát; khi chọn clip khác phải dừng/chuyển clip trước có kiểm soát; sau test trở về Idle.
- Đánh giá trực tiếp trên iPhone: động tác tay/chân/thân/đầu, biên độ, độ tự nhiên, độ giật, thời lượng, pose kết thúc, chuyển tiếp và lỗi rig.
- Sau khi clip được xác nhận bằng mắt, mới quyết định giữ/bỏ và tích hợp trigger theo ngữ cảnh. Test nút không chứng minh trigger tự động.
- Cụm nút và logic test chỉ là công cụ phát triển tạm thời. Khi hoàn tất chọn clip, mapping hội thoại và kiểm thử thực tế, phải gỡ UI test cùng code/test hooks không còn cần khỏi production.
- Không sửa Text Chat, Chibi Chat, chatbot/API, history hoặc voice pipeline khi chỉ bổ sung công cụ test Ara.

## Ara gesture test UI — trạng thái hiện tại
- Test UI được bật bằng icon `figure.stand` ở header Chat Voice; các nút hiển thị thành hai cột dọc hai bên Ara, có nút `Xong` để thoát chế độ test. User đã xác nhận nhìn thấy hai cột nút trên iPhone.
- Các nút test hiện có: Wave, Talk, Explain, Listen, Thinking, Empathy, AraLaugh, Laugh, Cheer, Cry và Idle.
- Mỗi clip test loop 7 giây rồi tự trở về Idle; chọn clip khác hủy lượt test trước. Voice/transcript/emotion callbacks không được ghi đè clip khi đang test.
- User đã test liên tiếp Wave → Talk → Explain; cả ba nút chạy đúng clip tương ứng, không bị gọi nhầm clip.
- User nhận xét Listen/AraListening, Thinking/AraThinking, Empathy/AraEmpathy và AraLaugh nhìn gần giống nhau, không tạo khác biệt trực quan đủ rõ trong lần test hiện tại.
- **Quyết định test tạm thời:** xem Idle là trạng thái nghỉ/trung tính mặc định, không gọi Idle là biểu cảm. Tạm gom Listen, Thinking, Empathy và AraLaugh vào nhóm clip nền/ít khác biệt; không ưu tiên các nút này trong lượt test kế tiếp. Không xóa enum, animation clip, timeline hoặc dữ liệu trong Release v4.
- Nếu sau này cần test sâu lại các trạng thái lắng nghe/suy nghĩ/đồng cảm/cười nhẹ hoặc có bộ asset/cử chỉ mới, đưa các nút Listen, Thinking, Empathy, AraLaugh trở lại cụm test để so sánh trực tiếp. Dữ liệu gốc v4 vẫn được giữ để tái sử dụng; không chạy lại GitHub Action chỉ để mở lại nút test.
- Các clip chưa có kết quả đánh giá trực quan đầy đủ: Laugh, Cheer, Cry. Tiếp tục test riêng trước khi quyết định mapping.
- Bố cục hai cột được commit tại `16d29cbb3af77a010390bbe8c8cc71b489ee370a`; commit status trước đó `3b95b0f9b79bdd1f41a18d281e3311a577f1abfc`. Build/iPhone verification của các thay đổi layout sau commit cần được ghi riêng khi có kết quả.
- Chỉ cập nhật UI test nếu user yêu cầu hoặc khi bước test kế tiếp đã được chốt; không tự ý sửa code trong lượt cập nhật status này.
