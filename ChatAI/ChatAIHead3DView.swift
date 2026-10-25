import SwiftUI
import RealityKit
import UIKit

/// Loads the USDZ generated from the uploaded GLB during CI. If RealityKit cannot load it,
/// a visible SwiftUI robot remains on screen instead of leaving an empty dark rectangle.
struct ChatAIHead3DView: View {
    var headRotation: Float = 0
    var speaking: Bool = false

    @State private var modelLoaded = false
    @State private var loadMessage = "Đang tải mô hình 3D…"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.04, blue: 0.075),
                    Color(red: 0.10, green: 0.035, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            FallbackCompanionRobot(speaking: speaking)
                .padding(.vertical, 8)
                .opacity(modelLoaded ? 0 : 1)

            CompanionRealityView(
                headRotation: headRotation,
                speaking: speaking,
                onResult: { success, message in
                    modelLoaded = success
                    loadMessage = message
                }
            )
            .opacity(modelLoaded ? 1 : 0)
            .allowsHitTesting(modelLoaded)
            .accessibilityHidden(!modelLoaded)

            if !modelLoaded {
                VStack {
                    Spacer()
                    Text(loadMessage)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.bottom, 6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .onAppear {
            // The RealityKit view performs the real load attempt once it is mounted.
            modelLoaded = false
        }
    }
}

private struct CompanionRealityView: UIViewRepresentable {
    let headRotation: Float
    let speaking: Bool
    let onResult: (Bool, String) -> Void

    private let modelResourceName = "model-1792924579279"

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.cameraMode = .nonAR
        view.environment.background = .color(
            UIColor(red: 0.025, green: 0.04, blue: 0.075, alpha: 1)
        )

        let scene = AnchorEntity(world: .zero)
        view.scene.addAnchor(scene)

        let camera = PerspectiveCamera()
        camera.position = [0, 0.02, 1.65]
        camera.look(at: [0, 0, 0], from: camera.position, relativeTo: nil)
        scene.addChild(camera)

        scene.addChild(makeLight(color: .white, intensity: 1300, position: [-0.45, 0.55, 0.65]))
        scene.addChild(makeLight(
            color: UIColor(red: 0.25, green: 0.7, blue: 1, alpha: 1),
            intensity: 800,
            position: [0.5, 0.15, 0.4]
        ))
        scene.addChild(makeLight(color: .white, intensity: 1000, position: [0, 0.45, -0.4]))

        // XcodeGen may place an explicitly declared resource at the bundle root.
        // Try both the root and the historical Companion subdirectory.
        let bundle = Bundle.main
        let directURL = bundle.url(forResource: modelResourceName, withExtension: "usdz")
            ?? bundle.url(
                forResource: modelResourceName,
                withExtension: "usdz",
                subdirectory: "Companion"
            )

        guard let url = directURL else {
            let resourceRoot = bundle.resourceURL
            let bundledFileExists = resourceRoot?.appendingPathComponent(
                "\(modelResourceName).usdz"
            ).path
            let detail = bundledFileExists.map { "Đã kiểm tra: \($0)" } ?? "Không đọc được thư mục tài nguyên ứng dụng."
            DispatchQueue.main.async {
                onResult(false, "Không tìm thấy USDZ trong app bundle. \(detail)")
            }
            return view
        }

        do {
            let model = try Entity.load(contentsOf: url)
            model.name = "ChatAICompanionGLB"

            // Normalize unknown model dimensions and center the visible geometry
            // so assets exported at different scales still fit the portrait camera.
            let bounds = model.visualBounds(relativeTo: model)
            let extents = bounds.extents
            let largestDimension = max(extents.x, max(extents.y, extents.z))
            guard largestDimension.isFinite, largestDimension > 0 else {
                throw NSError(
                    domain: "ChatAICompanion",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Mô hình GLB không có kích thước hiển thị hợp lệ."]
                )
            }
            let normalizedScale: Float = 1.18 / largestDimension
            model.scale = SIMD3<Float>(repeating: normalizedScale)
            model.position = -bounds.center * normalizedScale
            scene.addChild(model)
            context.coordinator.head = model
            DispatchQueue.main.async {
                onResult(true, "Đã tải mô hình 3D")
            }
        } catch {
            DispatchQueue.main.async {
                onResult(false, "Không tải được USDZ: \(error.localizedDescription)")
            }
        }

        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard let head = context.coordinator.head else { return }
        head.transform.rotation = simd_quatf(angle: headRotation, axis: [0, 1, 0])
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var head: Entity?
        weak var view: ARView?
    }

    private func makeLight(color: UIColor, intensity: Float, position: SIMD3<Float>) -> Entity {
        let light = Entity()
        var component = PointLightComponent()
        component.color = color
        component.intensity = intensity
        light.components.set(component)
        light.position = position
        return light
    }
}

private struct FallbackCompanionRobot: View {
    let speaking: Bool
    @State private var blink = false

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 330, geo.size.height / 390)
            VStack(spacing: 0) {
                HStack(spacing: 62 * s) {
                    antenna(scale: s)
                    antenna(scale: s)
                }
                .padding(.bottom, -4 * s)

                ZStack {
                    RoundedRectangle(cornerRadius: 82 * s)
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(red: 0.72, green: 0.86, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 82 * s)
                                .stroke(Color.pink.opacity(0.85), lineWidth: 5 * s)
                        )
                        .frame(width: 270 * s, height: 245 * s)
                        .shadow(color: .cyan.opacity(0.25), radius: 22 * s)

                    RoundedRectangle(cornerRadius: 58 * s)
                        .fill(Color(red: 0.015, green: 0.025, blue: 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 58 * s)
                                .stroke(Color.cyan.opacity(0.85), lineWidth: 3 * s)
                        )
                        .frame(width: 228 * s, height: 164 * s)
                        .overlay {
                            VStack(spacing: 22 * s) {
                                HStack(spacing: 40 * s) {
                                    eye(scale: s)
                                    eye(scale: s)
                                }
                                Capsule()
                                    .fill(Color.pink)
                                    .frame(width: (speaking ? 38 : 28) * s, height: (speaking ? 17 : 5) * s)
                                    .shadow(color: .pink.opacity(0.8), radius: 7 * s)
                            }
                        }

                    HStack(spacing: 0) {
                        ear(scale: s)
                        Spacer()
                        ear(scale: s)
                    }
                    .frame(width: 300 * s)
                }

                RoundedRectangle(cornerRadius: 12 * s)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.78), Color(white: 0.34), Color(white: 0.86)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 12 * s).stroke(Color.cyan, lineWidth: 2 * s))
                    .frame(width: 92 * s, height: 48 * s)
                    .overlay(Capsule().fill(Color.cyan).frame(width: 48 * s, height: 4 * s))

                Text("ChatAI")
                    .font(.system(size: 15 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan.opacity(0.9))
                    .padding(.top, 9 * s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func antenna(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Circle().fill(Color.pink).frame(width: 20 * scale, height: 20 * scale)
                .shadow(color: .pink.opacity(0.8), radius: 8 * scale)
            Capsule().fill(Color.cyan).frame(width: 5 * scale, height: 35 * scale)
        }
    }

    private func eye(scale: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.white, .cyan, Color.blue.opacity(0.8)],
                    center: .topLeading,
                    startRadius: 2,
                    endRadius: 34 * scale
                )
            )
            .frame(width: 42 * scale, height: 56 * scale)
            .overlay(Ellipse().fill(Color.black).frame(width: 17 * scale, height: 31 * scale))
            .overlay(Circle().fill(.white).frame(width: 9 * scale, height: 9 * scale).offset(x: -8 * scale, y: -13 * scale))
            .shadow(color: .cyan.opacity(0.85), radius: 8 * scale)
    }

    private func ear(scale: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 36 * scale, height: 36 * scale)
            .overlay(Circle().stroke(Color.pink, lineWidth: 4 * scale))
            .overlay(Circle().fill(Color.cyan).frame(width: 14 * scale, height: 14 * scale))
    }
}
