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

## Pipeline Ara đã xác minh — v4 là baseline, v5 đang chuẩn bị
- Workflow: `.github/workflows/generate-ara-usdz.yml` trên `main`, chạy thủ công. Upstream `olatunde85/3d-gen` pin tại `e26cdef1464a0babf23bb0235b5f05930301ee25`; USDZ Forge pin tại `d474129ce1f026fa6904c9ac95dd74212a501a9d`.
- **Luồng thực tế đã được xác minh từ log GitHub Action run #15 / run ID `41266922525`:**
  1. Job `generate` tạo GLB và upload artifact `ara-avatar-glb`.
  2. Job `convert` tải đúng artifact GLB đó bằng `actions/download-artifact@v4` (log ghi artifact ID `13067517492`), chạy `split-glb-animations.mjs`, compact GLB rồi chạy `usdzconvert` trên macOS để tạo `Ara-Avatar.usdz`.
  3. Job `convert` upload bộ đầu ra USDZ/research thành Actions artifact và publish các file tương ứng lên GitHub Release.
  4. **Codemagic không chuyển GLB sang USDZ.** Codemagic chỉ tải USDZ + timeline đã được Action tạo, sau đó dùng OpenUSD 26.5 để bake Hips sway, validate và đóng gói IPA.
- Release `ara-avatar-v4` đã phát hành và là baseline bất biến. Release chứa `Athletic_woman.glb` (17,534,748 bytes; SHA256 `5e922c88cb665593ab4c47973b6368df0205996f24290654a83d38cb47dd2e1e`), `Ara-Avatar.usdz` (25,500,329 bytes), timeline, research dataset nén, logs, diagnostics và checksums. Có thể tải GLB/research data từ Release để phân tích lại mà không chạy lại bước sinh GLB.
- Workflow hiện tại có input thủ công `source_run_id`: khi điền ID của một run còn artifact `ara-avatar-glb`, job `generate` được bỏ qua; job `convert` tải GLB từ run đó rồi tạo lại USDZ/research bundle. Nếu để trống, workflow mới sinh GLB upstream. Đây là cách tái sử dụng GLB đã có thay vì sinh lại; artifact GLB nguồn của run #15 cần còn hạn lưu trữ để tải qua Actions API. Nếu artifact hết hạn, dùng GLB đã lưu trong Release hoặc tạo một luồng tải GLB từ Release có kiểm tra checksum trước khi convert.
- **Codemagic hiện tại đang trỏ tag `ara-avatar-v5`**, và trước khi tải Release/Actions artifact còn kiểm tra latest successful workflow run cùng changed-file guard. Vì v5 chưa được tạo, Codemagic chưa thể lấy đúng bộ v5. Lỗi gần nhất xảy ra ngay tại changed-file guard, trước khi gọi API tải Release hoặc Actions artifact; không phải lỗi tải GLB hay convert USDZ. Không bỏ guard một cách mù quáng: cần xác định đúng source run, release tag và commit SHA rồi mới cho build tiếp tục.
- Khi build bằng v4, Codemagic phải pin rõ `ara-avatar-v4` và tải `Ara-Avatar.usdz` + `animation-timeline.json` từ Release v4. Khi build v5, chỉ chuyển sang tag v5 sau khi Action convert thành công và Release v5 được xác minh. Không lấy artifact mới nhất không ràng buộc run ID/tag.
- Run #15 (`41266922525`) thành công ngày 2026-11-01 tại commit `2af8ccd9385d06c1cdb7296fbcb51c8bf925535c`; Release v4 được publish. Log job convert xác nhận tải GLB artifact rồi convert USDZ. Không dispatch Action/Codemagic tự động.
- Nguồn có **75 animation clips, 69 joints, 34 morph targets**. Dataset đã kiểm tra: mỗi clip có 71 channels (69 rotation, 1 Hips translation, 1 blendshape weights), cùng target signature/output width, tất cả LINEAR; tổng thời lượng khoảng 138.59 giây.
- Runtime v4 chọn 11 conversation clips (~32.57 giây): 8 clip nền Idle, Wave, Talk, TalkExplain, AraListening, AraThinking, AraEmpathy, AraLaugh; thêm Cheer, Laugh, Cry. Các nhóm locomotion/combat/weapons/vehicles/sitting/lying hiện giữ trong research data, không thuộc runtime v4.
- Workflow v5 đã mở rộng danh mục clip runtime và có `source_run_id` để tái sử dụng GLB; v5 chưa được chạy/xác minh và chưa có Release v5.

## Trạng thái kỹ thuật đã xác minh
- Runtime log: Ara USDZ tải từ app bundle thành công (~25.5 MB); RealityKit import 1 global scene animation; app tạo 8 AnimationViews từ timeline.
- Log ghi nhận luồng voice connecting → live, nhận user/assistant messages, speaking true → false và chuyển clip. Đây là xác nhận tích hợp playback/voice state ở mức log.
- Playback đã thấy trong log: Idle → AraThinking → Wave → AraListening → Talk → Idle.
- `TalkExplain skipped: no explanation cue` trong lần test ngắn; đây là thiếu cue kích hoạt ở tình huống test, không phải bằng chứng clip bị lỗi.
- Người dùng quan sát Ara hơi lắc nhẹ khi nói và đôi lúc giơ tay phải rồi hạ nhanh; cần thêm clip/gesture có khác biệt rõ để đánh giá trực quan.
- Không kết luận chuyển động tự nhiên/chất lượng chỉ từ log; cần video/quan sát iPhone thật và kiểm thử từng clip.

## Việc tiếp theo
1. Đã hoàn tất lượt test trực quan Laugh, Cheer và Cry trên iPhone. Chưa đổi mapping tự động.
2. Laugh/Cheer chỉ cân nhắc cho tình huống cười lớn/cổ vũ mạnh; Cry không dùng làm cử chỉ khóc vì biểu hiện quan sát được sai sắc thái. Bước tiếp theo là quyết định giữ chúng ở chế độ test/thủ công hay tìm clip thay thế nhẹ nhàng, tự nhiên hơn.
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
- Bảng Test Ara nổi: kéo bằng riêng thanh tiêu đề; `@GestureState` cho kéo mượt, lưu offset khi thả. Cả hai điều khiển đều nằm BÊN TRONG thanh tiêu đề của khung: nút resize kéo ngang để chỉnh 55–125%, nút thu gọn đưa về icon 60×60pt. Không còn nút điều khiển đặt ngoài/ở chân khung. Commit: `ab8e9480b61a501993812a13227142dfe0e3998d`. Chưa build/chưa kiểm tra trên iPhone.
- Menu gồm một hàng ngang chọn nhóm (Biểu cảm, Di chuyển, Xoay, Tư thế, Nhảy, Khác) và danh sách chức năng một cột có thể cuộn dọc. Nhân vật Ara vẫn giữ kích thước khung hiển thị hiện tại; menu chỉ phủ một phần vùng phía trên khi mở.
- Chọn chức năng gọi trực tiếp clip tương ứng; mục đang chạy có dấu nhận biết. Jump sequence chạy Jump start → Jump air → Jump land → Idle.
- Mở chế độ test sẽ dừng phiên voice đang chạy như hành vi test hiện tại; đóng menu kết thúc test và trả Ara về Idle. Log chẩn đoán và nút sao chép log được giữ nguyên.
- Commit UI mới: `c199066b1616955a9f423f3b50b1df021aabb3ab` trên `main`. Chưa build Codemagic/chưa xác minh giao diện trên iPhone; cần user chạy build thủ công để test trực quan.
- Không sửa chatbot/API, voice pipeline, Text Chat hoặc Chibi Chat.
## Ara v5 — pipeline preparation in progress
- Main commit `a1b64e3af99e3f0705e2ec9b7f2e2fad3df5e64d` expands `scripts/split-glb-animations.mjs` to require the 19 additional source clips for the approved test actions, while retaining the existing 8 required conversation clips and 3 optional clips.
- `.github/workflows/generate-ara-usdz.yml` now publishes to the new immutable tag `ara-avatar-v5`; v4 remains unchanged. The existing GLB-to-USDZ conversion on macOS, texture packaging, USDZ inspection, timeline checks and research bundle generation are retained.
- `codemagic.yaml` now fetches and validates `ara-avatar-v5`, then continues using the existing OpenUSD 26.5 Hips-sway bake, USDZ validation and IPA-only packaging.
- This is pipeline preparation only. The Ara Swift runtime and test UI have not yet been expanded to expose/play the new clips. Do not dispatch the manual GitHub workflow or Codemagic build until runtime integration and validation are complete.
- No GitHub Actions/Codemagic run was started by the assistant. Release v5 has not yet been generated; release v4 remains the verified baseline.
