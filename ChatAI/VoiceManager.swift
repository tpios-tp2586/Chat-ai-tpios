import Foundation
import AVFoundation
import Speech

struct AzureTTS {
    static func speak(text: String, apiKey: String, region: String, gender: VoiceGender) async -> Data? {
        guard !apiKey.isEmpty, !region.isEmpty else { return nil }
        let voiceName = (gender == .female) ? "vi-VN-HoaiMyNeural" : "vi-VN-NamMinhNeural"
        let ssml = "<speak version='1.0' xml:lang='vi-VN'><voice name='\(voiceName)'>\(text)</voice></speak>"
        let urlString = "https://\(region).tts.speech.microsoft.com/cognitiveservices/v1"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("audio-24khz-48kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.httpBody = ssml.data(using: .utf8)
        guard let (data, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}

@MainActor
final class VoiceManager: NSObject, ObservableObject {
    @Published var isListening: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var voiceErrorMessage: String?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private let synthesizer = AVSpeechSynthesizer()
    private var azurePlayer: AVAudioPlayer?

    override init() { super.init(); synthesizer.delegate = self }

    func speak(text: String, gender: VoiceGender, azureKey: String, azureRegion: String) {
        guard !text.isEmpty else { return }
        Task {
            if !azureKey.isEmpty, !azureRegion.isEmpty, let data = await AzureTTS.speak(text: text, apiKey: azureKey, region: azureRegion, gender: gender) {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                    try session.setActive(true)
                    azurePlayer = try AVAudioPlayer(data: data)
                    azurePlayer?.play(); isSpeaking = true
                    while azurePlayer?.isPlaying == true { try? await Task.sleep(nanoseconds: 100_000_000) }
                    isSpeaking = false
                    return
                } catch { }
            }
            speakFallback(text: text, gender: gender)
        }
    }

    private func speakFallback(text: String, gender: VoiceGender) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch { return }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "vi-VN" }
        let target: AVSpeechSynthesisVoiceGender = gender == .male ? .male : .female
        let voice = voices.first { $0.gender == target } ?? voices.first ?? AVSpeechSynthesisVoice(language: "vi-VN")
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice; utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stopSpeaking() { azurePlayer?.stop(); azurePlayer = nil; synthesizer.stopSpeaking(at: .immediate); isSpeaking = false }

    func startListening(onPartialResult: @escaping (String) -> Void, onFinish: @escaping (String) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] micGranted in
            guard let self else { return }
            guard micGranted else { Task { @MainActor in self.voiceErrorMessage = "Chưa được cấp quyền micro. Vào Cài đặt → Chat AI → bật Micro." }; return }
            SFSpeechRecognizer.requestAuthorization { authStatus in
                Task { @MainActor in
                    guard authStatus == .authorized else { self.voiceErrorMessage = "Chưa được cấp quyền nhận diện giọng nói. Vào Cài đặt → Chat AI → bật Speech Recognition."; return }
                    self.beginRecognition(onPartialResult: onPartialResult, onFinish: onFinish)
                }
            }
        }
    }

    private func beginRecognition(onPartialResult: @escaping (String) -> Void, onFinish: @escaping (String) -> Void) {
        voiceErrorMessage = nil
        let engine = AVAudioEngine(); self.audioEngine = engine
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN")); self.speechRecognizer = recognizer
        guard recognizer?.isAvailable == true else { voiceErrorMessage = "Nhận diện giọng nói tiếng Việt không khả dụng lúc này."; return }
        recognitionTask?.cancel(); recognitionTask = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { voiceErrorMessage = "Lỗi khởi tạo audio: \(error.localizedDescription)"; return }
        let request = SFSpeechAudioBufferRecognitionRequest(); request.shouldReportPartialResults = true; recognitionRequest = request
        let inputNode = engine.inputNode
        let hwFormat = inputNode.inputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0 else { voiceErrorMessage = "Không đọc được micro. Thử khởi động lại app."; try? AVAudioSession.sharedInstance().setActive(false); return }
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { buffer, _ in request.append(buffer) }
        do { engine.prepare(); try engine.start() } catch { voiceErrorMessage = "Không khởi động được micro: \(error.localizedDescription)"; inputNode.removeTap(onBus: 0); try? AVAudioSession.sharedInstance().setActive(false); return }
        isListening = true
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString; let isFinal = result.isFinal
                Task { @MainActor in onPartialResult(text); if isFinal { self.stopListening(); onFinish(text) } }
            }
            if error != nil { Task { @MainActor in self.stopListening() } }
        }
    }

    func stopListening() {
        audioEngine?.stop(); audioEngine?.inputNode.removeTap(onBus: 0); audioEngine = nil
        recognitionRequest?.endAudio(); recognitionRequest = nil; recognitionTask?.cancel(); recognitionTask = nil; isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { Task { @MainActor in self.isSpeaking = true } }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { Task { @MainActor in self.isSpeaking = false } }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { Task { @MainActor in self.isSpeaking = false } }
}
