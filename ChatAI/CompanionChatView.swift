import SwiftUI

struct CompanionChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var liveManager = LiveVoiceManager()
    @AppStorage("live_model") private var liveModel = "gemini-3.8-live"
    @AppStorage("live_voice") private var liveVoice = "Zephyr"
    @AppStorage("live_persona") private var livePersona = LivePersona.defaultText
    @AppStorage("live_barge_in") private var liveBargeIn = false
    @State private var emotion: CompanionEmotion = .idle
    @State private var message: String?
    @State private var isNight = false

    var body: some View {
        ZStack {
            LinearGradient(colors: isNight ? [.black, Color(red: 0.10, green: 0.04, blue: 0.13)] : [Color(red: 0.035, green: 0.045, blue: 0.09), Color(red: 0.18, green: 0.07, blue: 0.15)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 42, height: 42).background(.white.opacity(0.12), in: Circle()) }
                    VStack(alignment: .leading, spacing: 2) { Text("ChatAI Companion").font(.headline); Text(viewModel.selectedProvider.rawValue).font(.caption).opacity(0.65) }
                    Spacer()
                    Button { isNight.toggle() } label: { Image(systemName: isNight ? "moon.stars.fill" : "sun.max.fill").frame(width: 42, height: 42).background(.white.opacity(0.12), in: Circle()) }
                }
                .foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 8)

                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        ApprovedRobotHead(emotion: emotion, isSpeaking: liveManager.aiSpeaking)
                            .frame(width: min(proxy.size.width - 12, 410), height: min(proxy.size.height * 0.72, 450))
                        Spacer(minLength: 6)
                        VStack(alignment: .leading, spacing: 7) {
                            Label(statusText, systemImage: statusIcon).font(.caption.weight(.semibold))
                            Text(message ?? viewModel.messages.last(where: { $0.role == .assistant })?.content ?? "Chào anh! Mình trò chuyện nhé.")
                                .font(.subheadline).lineLimit(2)
                        }
                        .foregroundStyle(.white).padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.10)))
                        .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 12) {
                    Button { if liveManager.state == .idle { startLive() } else { liveManager.end() } } label: {
                        Image(systemName: liveManager.state == .idle ? "mic.fill" : "stop.fill").frame(width: 52, height: 52).background(.white.opacity(0.14), in: Circle())
                    }
                    Button { if liveManager.state == .idle { startLive() } } label: {
                        Label(liveManager.state == .live ? (liveManager.aiSpeaking ? "AI đang nói..." : "Đang nghe anh") : (liveManager.state == .connecting ? "Đang kết nối..." : "Tiếp tục chat"), systemImage: "waveform")
                            .font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).frame(height: 52)
                            .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 52, height: 52).background(.red.opacity(0.85), in: Circle()) }
                }
                .foregroundStyle(.white).padding(16).background(.black.opacity(0.24))
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: liveManager.lines.count) { _ in if let line = liveManager.lines.last { message = line.text; emotion = line.role == .assistant ? .happy : .thinking } }
        .onChange(of: liveManager.aiSpeaking) { speaking in withAnimation(.easeInOut(duration: 0.15)) { emotion = speaking ? .speaking : (emotion == .speaking ? .idle : emotion) } }
        .onChange(of: liveManager.state) { state in
            guard !liveManager.aiSpeaking else { return }
            emotion = state == .live ? .listening : (state == .connecting ? .thinking : .idle)
        }
        .onDisappear { liveManager.end() }
    }

    private func startLive() { liveManager.start(model: liveModel, voice: liveVoice, persona: livePersona, bargeIn: liveBargeIn) }
    private var statusText: String { switch emotion { case .idle: "Đang ở đây với anh"; case .listening: "Em đang nghe anh"; case .thinking: "Đang suy nghĩ"; case .speaking: "Em đang nói"; case .happy: "Em đang vui"; case .surprised: "Bất ngờ quá!"; case .confused: "Để em nghĩ lại..."; case .sad: "Em hơi buồn..."; case .angry: "Em đang giận đó nha"; case .sleepy: "Em hơi buồn ngủ..." } }
    private var statusIcon: String { switch emotion { case .idle: "sparkles"; case .listening: "ear"; case .thinking: "ellipsis.bubble"; case .speaking: "waveform"; case .happy: "face.smiling"; case .surprised: "exclamationmark.bubble"; case .confused: "questionmark.bubble"; case .sad: "cloud.rain"; case .angry: "flame"; case .sleepy: "moon.zzz" } }
}

private enum CompanionEmotion { case idle, listening, thinking, speaking, happy, surprised, confused, sad, angry, sleepy }

/// Geometry intentionally follows the approved concept: wide low helmet, thin pink bezel,
/// very large black visor, small side ear modules, and the eyes placed high enough to read as a face.
private struct ApprovedRobotHead: View {
    let emotion: CompanionEmotion
    let isSpeaking: Bool
    @State private var blink = false
    @State private var float = false
    @State private var look: CGFloat = 0
    @State private var mouthOpen = false

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 410, geo.size.height / 450)
            ZStack {
                Circle().fill(Color.cyan.opacity(0.10)).frame(width: 330*s, height: 330*s).blur(radius: 48)

                // Rear fins: three separated translucent blades, as in the concept sheet.
                SideFin(x: 53*s, y: 282*s, flip: false, s: s)
                SideFin(x: 357*s, y: 282*s, flip: true, s: s)

                // Main helmet silhouette: wide oval/rounded capsule, NOT a rectangular card.
                HelmetShell(s: s)

                // Ear/headphone modules overlap the shell sides.
                EarModule(s: s).position(x: 32*s, y: 240*s)
                EarModule(s: s).position(x: 378*s, y: 240*s)

                // Antennae are anchored into the top shell.
                Antenna(x: 139*s, angle: -13, s: s)
                Antenna(x: 271*s, angle: 13, s: s)

                // Wide glossy visor follows the shell curvature.
                Visor(s: s)

                // Eyes are large, round cyan rings with dark centered pupils and specular highlights.
                ConceptEye(s: s, height: blink ? 4 : eyeHeight, pupilX: look).position(x: 142*s, y: 232*s)
                ConceptEye(s: s, height: blink ? 4 : eyeHeight, pupilX: look).position(x: 268*s, y: 232*s)

                Brow(s: s, side: -1, emotion: emotion).position(x: 142*s, y: 191*s)
                Brow(s: s, side: 1, emotion: emotion).position(x: 268*s, y: 191*s)

                Capsule().fill(Color(red: 1, green: 0.38, blue: 0.67)).frame(width: 31*s, height: 10*s).rotationEffect(.degrees(-6)).position(x: 94*s, y: 293*s)
                Capsule().fill(Color(red: 1, green: 0.38, blue: 0.67)).frame(width: 31*s, height: 10*s).rotationEffect(.degrees(6)).position(x: 316*s, y: 293*s)

                Mouth(s: s, emotion: emotion, speaking: isSpeaking, open: mouthOpen).position(x: 205*s, y: 293*s)
            }
            .frame(width: 410*s, height: 450*s)
            .offset(y: float ? -3*s : 3*s)
            .position(x: geo.size.width/2, y: geo.size.height/2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { look = 2.5 }
                Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 3_400_000_000)
                        withAnimation(.easeInOut(duration: 0.07)) { blink = true }
                        try? await Task.sleep(nanoseconds: 90_000_000)
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { blink = false }
                    }
                }
            }
            .onChange(of: isSpeaking) { value in
                if value { withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) { mouthOpen = true } }
                else { mouthOpen = false }
            }
        }
    }

    private var eyeHeight: CGFloat { switch emotion { case .surprised: 73; case .sleepy: 32; case .happy: 55; case .angry: 47; default: 66 } }
}

private struct HelmetShell: View {
    let s: CGFloat
    var body: some View {
        ZStack {
            HelmetShape()
                .fill(LinearGradient(colors: [.white, Color(red: 0.98, green: 0.94, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 350*s, height: 276*s)
                .overlay(HelmetShape().stroke(Color(red: 1, green: 0.56, blue: 0.78), lineWidth: 10*s))
                .overlay(HelmetShape().stroke(.white.opacity(0.90), lineWidth: 2*s).padding(8*s))
                .shadow(color: Color.pink.opacity(0.35), radius: 18*s, y: 10*s)
        }
    }
}

private struct HelmetShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let w=r.width, h=r.height
        p.move(to: CGPoint(x: w*0.18, y: h*0.13))
        p.addCurve(to: CGPoint(x: w*0.82, y: h*0.13), control1: CGPoint(x: w*0.32, y: -h*0.01), control2: CGPoint(x: w*0.68, y: -h*0.01))
        p.addCurve(to: CGPoint(x: w*0.96, y: h*0.43), control1: CGPoint(x: w*0.94, y: h*0.18), control2: CGPoint(x: w*0.98, y: h*0.30))
        p.addCurve(to: CGPoint(x: w*0.88, y: h*0.82), control1: CGPoint(x: w*0.97, y: h*0.58), control2: CGPoint(x: w*0.96, y: h*0.72))
        p.addCurve(to: CGPoint(x: w*0.67, y: h*0.95), control1: CGPoint(x: w*0.82, y: h*0.93), control2: CGPoint(x: w*0.73, y: h*0.98))
        p.addCurve(to: CGPoint(x: w*0.33, y: h*0.95), control1: CGPoint(x: w*0.58, y: h*0.98), control2: CGPoint(x: w*0.42, y: h*0.98))
        p.addCurve(to: CGPoint(x: w*0.12, y: h*0.82), control1: CGPoint(x: w*0.27, y: h*0.98), control2: CGPoint(x: w*0.18, y: h*0.93))
        p.addCurve(to: CGPoint(x: w*0.04, y: h*0.43), control1: CGPoint(x: w*0.02, y: h*0.72), control2: CGPoint(x: w*0.03, y: h*0.58))
        p.addCurve(to: CGPoint(x: w*0.18, y: h*0.13), control1: CGPoint(x: w*0.02, y: h*0.30), control2: CGPoint(x: w*0.06, y: h*0.18))
        p.closeSubpath(); return p
    }
}

private struct Visor: View {
    let s: CGFloat
    var body: some View {
        VisorShape().fill(LinearGradient(colors: [Color(red: 0.025, green: 0.03, blue: 0.045), .black], startPoint: .top, endPoint: .bottom))
            .frame(width: 306*s, height: 190*s)
            .overlay(VisorShape().stroke(Color(red: 1, green: 0.64, blue: 0.82), lineWidth: 5*s))
            .overlay(VisorShape().stroke(.white.opacity(0.12), lineWidth: 2*s).padding(7*s))
            .overlay(alignment: .topLeading) { Capsule().fill(.white.opacity(0.22)).frame(width: 58*s, height: 13*s).rotationEffect(.degrees(-28)).offset(x: 42*s, y: 20*s) }
            .shadow(color: .black.opacity(0.55), radius: 12*s, y: 8*s)
            .position(x: 205*s, y: 238*s)
    }
}

private struct VisorShape: Shape {
    func path(in r: CGRect) -> Path {
        var p=Path(); let w=r.width,h=r.height
        p.move(to: CGPoint(x:w*0.18,y:h*0.03)); p.addCurve(to: CGPoint(x:w*0.82,y:h*0.03), control1: CGPoint(x:w*0.33,y:-0.01*h), control2: CGPoint(x:w*0.67,y:-0.01*h))
        p.addCurve(to: CGPoint(x:w*0.98,y:h*0.34), control1: CGPoint(x:w*0.96,y:h*0.12), control2: CGPoint(x:w*1.01,y:h*0.22))
        p.addCurve(to: CGPoint(x:w*0.91,y:h*0.78), control1: CGPoint(x:w*0.98,y:h*0.55), control2: CGPoint(x:w*0.96,y:h*0.70))
        p.addCurve(to: CGPoint(x:w*0.77,y:h*0.95), control1: CGPoint(x:w*0.88,y:h*0.87), control2: CGPoint(x:w*0.84,y:h*0.96))
        p.addCurve(to: CGPoint(x:w*0.23,y:h*0.95), control1: CGPoint(x:w*0.70,y*h*0+h*0.96), control2: CGPoint(x:w*0.30,y:h*0.96))
        p.addCurve(to: CGPoint(x:w*0.09,y:h*0.78), control1: CGPoint(x:w*0.16,y:h*0.96), control2: CGPoint(x:w*0.12,y:h*0.87))
        p.addCurve(to: CGPoint(x:w*0.02,y:h*0.34), control1: CGPoint(x:w*0.04,y:h*0.70), control2: CGPoint(x:w*0.02,y:h*0.55))
        p.addCurve(to: CGPoint(x:w*0.18,y:h*0.03), control1: CGPoint(x:-0.01*w,y:h*0.22), control2: CGPoint(x:w*0.04,y:h*0.12)); p.closeSubpath(); return p
    }
}

private struct ConceptEye: View {
    let s: CGFloat; let height: CGFloat; let pupilX: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color.cyan.opacity(0.28)).frame(width: 78*s, height: 78*s).blur(radius: 10*s)
            Circle().fill(LinearGradient(colors: [Color(red:0.80,green:1,blue:1),Color(red:0.10,green:0.92,blue:1),Color(red:0,green:0.45,blue:0.68)], startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width: 62*s, height: height*s).overlay(Circle().stroke(Color(red:0.50,green:1,blue:1),lineWidth:3*s)).shadow(color:.cyan.opacity(0.85),radius:8*s)
            Circle().fill(Color(red:0.02,green:0.20,blue:0.25)).frame(width: 35*s, height: 47*s).offset(x:pupilX)
            Capsule().fill(Color.black).frame(width: 14*s, height: 31*s).offset(x:pupilX)
            Circle().fill(.white).frame(width: 16*s,height:16*s).offset(x:-13*s,y:-18*s)
            Circle().fill(.white.opacity(0.9)).frame(width: 7*s,height:7*s).offset(x:11*s,y:16*s)
        }
    }
}

private struct Brow: View {
    let s: CGFloat; let side: CGFloat; let emotion: CompanionEmotion
    var body: some View { Capsule().fill(Color.cyan.opacity(0.80)).frame(width: 42*s,height: 5*s).rotationEffect(.degrees(angle)).shadow(color:.cyan.opacity(0.6),radius:4*s) }
    private var angle: Double { switch emotion { case .angry: side < 0 ? 22 : -22; case .sad: side < 0 ? -15 : 15; case .thinking: side < 0 ? -9 : 9; case .confused: side < 0 ? -12 : 15; default: side < 0 ? -5 : 5 } }
}

private struct Mouth: View {
    let s: CGFloat; let emotion: CompanionEmotion; let speaking: Bool; let open: Bool
    var body: some View {
        if speaking || emotion == .surprised { Capsule().fill(.black).frame(width:(open ? 40:27)*s,height:(open ? 23:10)*s).overlay(Capsule().stroke(Color.pink,lineWidth:3*s)).shadow(color:.pink.opacity(0.7),radius:6*s) }
        else { HStack(spacing:-2*s) { Capsule().fill(Color.pink).frame(width:16*s,height:5*s).rotationEffect(.degrees(emotion == .sad ? -25 : 25)); Capsule().fill(Color.pink).frame(width:16*s,height:5*s).rotationEffect(.degrees(emotion == .sad ? 25 : -25)) } }
    }
}

private struct EarModule: View {
    let s: CGFloat
    var body: some View { ZStack { Circle().fill(.white).frame(width:76*s,height:76*s).overlay(Circle().stroke(Color.pink,lineWidth:7*s)); Circle().fill(Color(red:0.43,green:0.84,blue:1)).frame(width:51*s,height:51*s).overlay(Circle().stroke(Color(red:1,green:0.72,blue:0.88),lineWidth:4*s)); Image(systemName:"sparkle").foregroundStyle(.white).font(.system(size:18*s,weight:.bold)) } }
}

private struct SideFin: View {
    let x: CGFloat; let y: CGFloat; let flip: Bool; let s: CGFloat
    var body: some View { ZStack { FinShape().fill(Color(red:0.65,green:0.88,blue:1).opacity(0.55)).frame(width:82*s,height:110*s).overlay(FinShape().stroke(Color.pink.opacity(0.65),lineWidth:3*s)); VStack(spacing:10*s){ Capsule().fill(.white.opacity(0.75)).frame(width:48*s,height:2*s); Capsule().fill(.white.opacity(0.75)).frame(width:57*s,height:2*s); Capsule().fill(.white.opacity(0.75)).frame(width:42*s,height:2*s) } }.scaleEffect(x:flip ? -1:1).position(x:x,y:y) }
}
private struct FinShape: Shape { func path(in r:CGRect)->Path { var p=Path(); p.move(to:CGPoint(x:r.midX,y:0)); p.addCurve(to:CGPoint(x:r.maxX,y:r.height*0.42),control1:CGPoint(x:r.maxX*1.02,y:0),control2:CGPoint(x:r.maxX*1.03,y:r.height*0.22)); p.addCurve(to:CGPoint(x:r.midX,y:r.maxY),control1:CGPoint(x:r.maxX,y:r.height*0.85),control2:CGPoint(x:r.width*0.68,y:r.maxY)); p.addCurve(to:CGPoint(x:0,y:r.height*0.45),control1:CGPoint(x:r.width*0.15,y:r.maxY),control2:CGPoint(x:-r.width*0.02,y:r.height*0.62)); p.addCurve(to:CGPoint(x:r.midX,y:0),control1:CGPoint(x:r.width*0.18,y:r.height*0.10),control2:CGPoint(x:r.width*0.35,y:0)); p.closeSubpath(); return p } }

private struct Antenna: View {
    let x: CGFloat; let angle: Double; let s: CGFloat
    var body: some View { ZStack { Capsule().fill(Color(red:0.45,green:0.84,blue:1)).frame(width:6*s,height:50*s).rotationEffect(.degrees(angle)); Circle().fill(Color.pink.opacity(0.28)).frame(width:38*s,height:38*s).blur(radius:6*s); Circle().fill(LinearGradient(colors:[.white,Color.pink],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:28*s,height:28*s).overlay(Circle().stroke(.white.opacity(0.9),lineWidth:2*s)); Circle().fill(.white.opacity(0.8)).frame(width:7*s,height:7*s).offset(x:-5*s,y:-5*s) }.position(x:x,y:49*s) }
}
