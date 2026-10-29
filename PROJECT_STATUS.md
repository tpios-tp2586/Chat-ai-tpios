# PROJECT_STATUS.md — ChatAI

## Mục đích
Đây là tài liệu bàn giao duy nhất để mở chat mới và tiếp tục đúng công việc. Khi làm việc, luôn đối chiếu với code và log thực tế trong repo; tài liệu này không thay thế việc kiểm tra.

## Repo và quy tắc làm việc
- Repo: https://github.com/tpios-tp2586/Chat-ai-tpios
- Chỉ làm việc trên nhánh `main`. Không tạo nhánh mới.
- Trước khi sửa, kiểm tra trạng thái repo, file liên quan và lỗi/log mới nhất.
- Thay đổi tối thiểu; không tự ý sửa hoặc làm hỏng chatbot, lịch sử chat và giọng nói đang hoạt động.
- Không tuyên bố build hoặc tính năng thành công nếu chưa có bằng chứng kiểm chứng.
- Không sao chép hay nhúng nguyên sản phẩm/code từ repo bên ngoài. Chỉ dùng tài liệu và dự án khác để nghiên cứu; phải xem xét giấy phép và khả năng tương thích.
- Ưu tiên giải pháp miễn phí, chạy được trên iOS và quy trình thao tác bằng iPhone/Codemagic.

## Công việc hiện tại
Phát triển avatar cô gái AI 3D trong ChatAI, tách biệt hợp lý với giao diện chat hiện có. Ưu tiên ngôn ngữ cơ thể và cử chỉ phù hợp nội dung/giọng nói hơn là làm gương mặt thật ngay từ đầu.

### Mục tiêu avatar
- Ưu tiên phần thân trên, vai, cánh tay và bàn tay.
- Cử chỉ cần hướng tới: chào, mở lòng bàn tay, giải thích, đếm ý, gật đầu, đặt câu hỏi, vui vẻ, đồng cảm, ngạc nhiên và nghiêm túc.
- Đồng bộ cử chỉ với TTS/nội dung câu trả lời; tránh chuyển động ngẫu nhiên, lặp lại hoặc máy móc.
- Khẩu hình đồng bộ giọng nói vẫn là mục tiêu quan trọng; gương mặt ban đầu có thể đơn giản với mắt, miệng và biểu cảm cơ bản.
- Không tích hợp thử nghiệm vào luồng chat chính cho đến khi có demo chạy được và được kiểm tra.

## Trạng thái và điều chưa xác nhận
- Avatar 3D và cử chỉ vẫn là phần việc đang phát triển, chưa được xác nhận hoàn thành.
- Trước khi tiếp tục, kiểm tra code, asset, cấu trúc project và log build hiện tại trên `main`; không suy đoán trạng thái từ tài liệu này.
- Thử nghiệm avatar web trước đây từng gây màn hình đen và đã bị loại bỏ/hoàn nguyên theo trao đổi trước. Không đưa lại thử nghiệm đó.
- Chưa xác nhận trong tài liệu này thư viện 3D nào đã được chọn hoặc chạy thành công trên project hiện tại.
- Các ứng viên từng được nêu để nghiên cứu, chưa được xác nhận tích hợp: VRMKit, VRMMetalKit. Chỉ xem xét sau khi kiểm tra tài liệu, giấy phép, yêu cầu iOS và demo thực tế.

## Việc tiếp theo
1. Kiểm tra nhánh `main`, commit mới nhất, file avatar/voice liên quan và log build mới nhất.
2. Xác định những gì hiện có trong repo: mô hình/asset, rig, animation, TTS và điểm tích hợp.
3. Nghiên cứu một phương án miễn phí, phù hợp iOS; ghi rõ điều gì đã xác minh và điều gì chưa.
4. Dựng demo nhỏ để kiểm tra tải mô hình, chuyển động cơ thể/cử chỉ và đồng bộ với lời nói trước khi tích hợp.
5. Chỉ sau khi demo hoạt động mới đề xuất thay đổi tối thiểu cho ứng dụng chính; bảo toàn các chức năng hiện có.
6. Sau mỗi thay đổi, ghi lại commit, file đã đổi, cách kiểm tra, kết quả build và lỗi còn lại trong chính file này.

## Quy trình mở chat mới
Dán đoạn sau vào chat mới:

> Tiếp tục dự án ChatAI từ repo https://github.com/tpios-tp2586/Chat-ai-tpios. Trước tiên đọc PROJECT_STATUS.md, kiểm tra code và log thực tế trên main. Chỉ làm trên main, không tạo nhánh. Không tự ý thay đổi chatbot, lịch sử chat hoặc giọng nói đang hoạt động. Tiếp tục từ việc còn dang dở; nghiên cứu và kiểm chứng demo avatar 3D/cử chỉ trước khi tích hợp. Ưu tiên thay đổi tối thiểu, giải pháp miễn phí và không báo thành công nếu chưa có bằng chứng. Cập nhật PROJECT_STATUS.md sau khi có thay đổi hoặc kết quả kiểm thử.

## Nhật ký cập nhật
- Tạo tài liệu bàn giao tập trung để chat mới nắm mục tiêu, quy tắc và bước tiếp theo.
- Chưa thực hiện thay đổi code ứng dụng trong lần cập nhật tài liệu này.
