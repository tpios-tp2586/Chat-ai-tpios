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

## Pipeline Ara hiện tại — nghiên cứu inventory hoàn tất, chưa chạy Action mới
- Workflow tạo asset: `.github/workflows/generate-ara-usdz.yml` trên `main`, chạy thủ công. Upstream `olatunde85/3d-gen` được pin tại `e26cdef1464a0babf23bb0235b5f05930301ee25`.
- Release `ara-avatar-v3` giữ GLB nguồn `Athletic_woman.glb`, USDZ 8 clip, timeline, diagnostics và `ara-research-data.json.gz`. Research bundle hiện đã được tải và phân tích offline; không cần chạy lại upstream để nghiên cứu 75 clip.
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
- Workflow trên `main` hiện phát hành tag mới `ara-avatar-v4`, `overwrite_files: false`; release body mô tả bộ tối đa 11 clip. Không ghi đè v3.
- Các cập nhật code chuẩn bị cho bộ 11 clip đã commit trên `main`; **chưa chạy Action mới, chưa tạo ara-avatar-v4 và chưa build Codemagic**. Release v3 vẫn là asset đã xác minh hiện có, chỉ chứa 8 clip.

## Trạng thái kỹ thuật đã xác minh
- Runtime log: Ara USDZ tải từ app bundle thành công (~25.5 MB); RealityKit import 1 global scene animation; app tạo 8 AnimationViews từ timeline.
- Log ghi nhận luồng voice connecting → live, nhận user/assistant messages, speaking true → false và chuyển clip. Đây là xác nhận tích hợp playback/voice state ở mức log.
- Playback đã thấy trong log: Idle → AraThinking → Wave → AraListening → Talk → Idle.
- `TalkExplain skipped: no explanation cue` trong lần test ngắn; đây là thiếu cue kích hoạt ở tình huống test, không phải bằng chứng clip bị lỗi.
- Người dùng quan sát Ara hơi lắc nhẹ khi nói và đôi lúc giơ tay phải rồi hạ nhanh; cần thêm clip/gesture có khác biệt rõ để đánh giá trực quan.
- Không kết luận chuyển động tự nhiên/chất lượng chỉ từ log; cần video/quan sát iPhone thật và kiểm thử từng clip.

## Việc tiếp theo
1. Review toàn bộ diff trên `main` cho bộ conversation 11 clips và các diagnostics; không tạo thêm clip thử rời rạc.
2. Khi đã chốt review, user chạy GitHub Action **một lần duy nhất** trên `main` để tạo Release `ara-avatar-v4`; kiểm tra timeline có 11 clips, diagnostics, USDZ texture/package và SHA256.
3. Chỉ sau khi v4 được xác minh, user chạy Codemagic để bake Hips sway 5° và build IPA (artifact chỉ IPA).
4. Test 11 clips trên iPhone thật: đặc biệt so sánh AraLaugh với Laugh; Cheer và Cry chỉ test thủ công; kiểm tra chuyển tiếp về Talk/Idle và không giật.
5. Sau test mới quyết định mapping tự động theo ngữ cảnh, thêm gesture procedural nếu còn thiếu; lip-sync/viseme vẫn là giai đoạn riêng.

## Build và xác minh
- Codemagic workflow chính: `ios-unsigned`; assistant không dispatch Codemagic trực tiếp.
- Build simulator chỉ xác nhận compile/package, không thay thế kiểm thử trên iPhone thật.
- Không build IPA từ asset mới trước khi review kết quả USDZ post-conversion.

## Rà soát pipeline trước Action v4 — 2026-11-01
- Đã sửa workflow tạo USDZ: bỏ điều kiện cố định `endTimeCode=780`; giờ tính FPS và endTimeCode kỳ vọng trực tiếp từ `animation-timeline.json`, rồi đối chiếu với báo cáo USDZ (sai lệch tối đa 1 timecode).
- Đã siết Codemagic: chỉ chấp nhận artifact `ara-avatar-research-bundle` thuộc **lần chạy Ara workflow thành công mới nhất trên main**, và SHA của workflow run phải trùng SHA hiện tại của `main`. Nếu Action chưa chạy thành công trên commit hiện tại, Codemagic dừng thay vì âm thầm lấy artifact cũ.
- Codemagic vẫn chỉ đóng gói IPA; không thêm ZIP artifact riêng.
- Các cập nhật nằm trên `main`; không tạo nhánh. Sau commit trạng thái này, user cần chạy Action một lần trên đúng HEAD hiện tại; chỉ khi Action thành công mới chạy Codemagic.
- Chưa chạy Action hoặc Codemagic trong đợt sửa này. Chưa xác minh runtime của bộ 11 clip trên iPhone; việc đó vẫn cần sau khi có asset v4.
