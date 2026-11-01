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

## Pipeline Ara hiện tại — trạng thái và giới hạn đã xác minh
- Workflow tạo asset: `.github/workflows/generate-ara-usdz.yml` trên `main`, chạy thủ công.
- Upstream: https://github.com/olatunde85/3d-gen, pin commit `e26cdef1464a0babf23bb0235b5f05930301ee25`.
- Nguồn GLB hiện có 75 animation clips; rig GLB đã kiểm tra có 69 joints và 34 morph targets.
- **Giới hạn hiện tại:** `scripts/split-glb-animations.mjs` chỉ chọn 8 clip (Idle, Wave, Talk, TalkExplain, AraListening, AraThinking, AraEmpathy, AraLaugh), ghép thành timeline 26 giây; script yêu cầu các clip có cùng rig channels, output shape và LINEAR interpolation.
- Release `ara-avatar-v3` hiện đã lưu GLB nguồn 75 animation cùng `ara-research-data.json.gz` (dữ liệu kênh animation GLB), USDZ hiện tại, timeline và diagnostics. Có thể dùng GLB/research dataset trong Release để nghiên cứu clip khác mà không sinh lại GLB upstream.
- Tuy nhiên USDZ hiện tại chỉ chứa timeline 8 clip nói trên; research dataset có dữ liệu kênh của 75 clip GLB nhưng phần USDZ samples chỉ mô tả USDZ 8 clip. Không nhầm dữ liệu nghiên cứu GLB với việc app đã có thể phát mọi clip trong USDZ.
- Trước đợt tạo asset tổng hợp tiếp theo: bổ sung báo cáo inventory đủ 75 clip (tên, duration, số channels, joints/paths, interpolation, rig compatibility); đánh giá clip hữu ích theo danh mục cử chỉ; chọn bộ đầy đủ để test và phát triển; sau đó mới ghép timeline/convert/validate một lần.
- Workflow hiện tại dùng tag `ara-avatar-v3` và `overwrite_files=true`; cần sửa quy trình phát hành sang tag/version mới bất biến cho bộ asset tổng hợp kế tiếp, không ghi đè dữ liệu Release cũ.
- Workflow hiện tạo `Ara-Avatar.usdz` chưa bake Hips sway, marker `hips_sway_baked=false`, timeline và research bundle. Hips sway được bake ở Codemagic trước Xcode build bằng `scripts/apply-ara-hip-sway.py` (Hips Y ±3°, 0.8 Hz, 30 FPS, clip Talk và AraListening).
- Runtime Hips sway additive đã được bỏ khỏi `AraAvatarView.swift`; sway được bake vào USDZ ở bước Codemagic.
- Script chính: `scripts/split-glb-animations.mjs`, `scripts/compact-glb-primitives.mjs`, `scripts/apply-ara-talk-explain.mjs`, `scripts/inspect-ara-animation.mjs`, `scripts/ara-research-data.py`, `scripts/inspect-ara-usdz-animation.py`, `scripts/apply-ara-hip-sway.py`.
- Codemagic `ios-unsigned` tải Ara research bundle, kiểm tra marker, cài OpenUSD trong Python virtualenv tạm, bake Hips sway, kiểm tra USDZ rồi build IPA. OpenUSD không được thêm vào app.

## Trạng thái kỹ thuật đã xác minh
- Runtime log: Ara USDZ tải từ app bundle thành công (~25.5 MB); RealityKit import 1 global scene animation; app tạo 8 AnimationViews từ timeline.
- Log ghi nhận luồng voice connecting → live, nhận user/assistant messages, speaking true → false và chuyển clip. Đây là xác nhận tích hợp playback/voice state ở mức log.
- Playback đã thấy trong log: Idle → AraThinking → Wave → AraListening → Talk → Idle.
- `TalkExplain skipped: no explanation cue` trong lần test ngắn; đây là thiếu cue kích hoạt ở tình huống test, không phải bằng chứng clip bị lỗi.
- Người dùng quan sát Ara hơi lắc nhẹ khi nói và đôi lúc giơ tay phải rồi hạ nhanh; cần thêm clip/gesture có khác biệt rõ để đánh giá trực quan.
- Không kết luận chuyển động tự nhiên/chất lượng chỉ từ log; cần video/quan sát iPhone thật và kiểm thử từng clip.

## Việc tiếp theo
1. Nghiên cứu inventory đầy đủ 75 animation từ GLB/research dataset đã lưu trong Release hiện tại; phân loại theo danh mục cử chỉ ở trên, không chạy Action.
2. Kiểm tra clip nào dùng được ngay, clip nào thiếu, clip nào trùng lặp/không phù hợp; xác minh compatibility của rig channels và converter trước khi chốt bộ master.
3. Chuẩn bị một thay đổi gộp cho workflow/scripts: master USDZ/timeline đầy đủ cho bộ clip đã duyệt, manifest dễ tra cứu, diagnostics per-clip, research data và Release version mới bất biến.
4. Chỉ sau khi review xong toàn bộ thay đổi mới báo user chạy GitHub Action thủ công một lần; sau khi Release asset hoàn tất mới chạy Codemagic để bake/đóng gói và build IPA.
5. Test trên iPhone thật từng nhóm cử chỉ và chuyển tiếp; sau đó mới phát triển logic chọn gesture theo ngữ cảnh. Lip-sync/viseme làm ở giai đoạn sau.

## Build và xác minh
- Codemagic workflow chính: `ios-unsigned`; assistant không dispatch Codemagic trực tiếp.
- Build simulator chỉ xác nhận compile/package, không thay thế kiểm thử trên iPhone thật.
- Không build IPA từ asset mới trước khi review kết quả USDZ post-conversion.
