# Chat AI TPios — Project Status

## Ara Avatar — Trạng thái hiện tại (2026-11-07)

### Kiến trúc hiện tại
- Load `Ara-Avatar.usdz` một lần duy nhất từ bundle
- `availableAnimations` trả về 27 clips — dùng index để play
- `stopAllAnimations()` sau khi load, trước khi phát Idle
- Emotion system: idle → listening → thinking → speaking (wave+talk loop) → happy/surprised/empathy

### Index clip đã xác nhận (batch-30 test, ara-avatar-v5)
- 0=Idle, 1=Wave, 2=Talk, 3=TalkExplain, 4=AraListening, 5=AraThinking
- 6=AraEmpathy, 7=AraLaugh, 8=Walk, 9=Run ... 27=Cheer

### Vấn đề cần xác nhận sau build
1. `stopAllAnimations()` có block được USDZ autoplay không
2. Index 0–7 và 27 có đúng clip không (log `[ARA] play[N] Name`)
3. Ara đứng im lúc không trò chuyện
4. Ara chạy đúng clip khi trò chuyện

### Files không được đụng
- `LiveVoice.swift`, `ChatViewModel.swift`, `Services.swift`
- audio pipeline, chat history, Text Chat, Chibi Chat

### Build pipeline
- Codemagic download `Ara-Avatar.usdz` từ release `ara-avatar-v5`
- Validate bằng `inspect-ara-usdz-animation.py`
- Xcode build → IPA unsigned

### Commit gần nhất
- `2628b92` — load single USDZ, index-based clip playback
- `9c7da2e` — codemagic.yaml reverted + allowed split-ara-clips.py
- `f52cf2c` — codemagic.yaml reverted về 23a38c0 (working build)
