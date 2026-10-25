import SwiftUI
import RealityKit
import UIKit

/// Displays the real GLB companion asset bundled with the app.
/// Asset path: ChatAI/Resources/Companion/model-1792924579279.glb.
struct ChatAIHead3DView: UIViewRepresentable {
    var headRotation: Float = 0
    var speaking: Bool = false

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

        scene.addChild(makeLight(
            color: .white,
            intensity: 1300,
            position: [-0.45, 0.55, 0.65]
        ))
        scene.addChild(makeLight(
            color: UIColor(red: 0.25, green: 0.7, blue: 1, alpha: 1),
            intensity: 800,
            position: [0.5, 0.15, 0.4]
        ))
        scene.addChild(makeLight(
            color: .white,
            intensity: 1000,
            position: [0, 0.45, -0.4]
        ))

        let modelURL = Bundle.main.url(
            forResource: modelResourceName,
            withExtension: "glb",
            subdirectory: "Companion"
        ) ?? Bundle.main.url(
            forResource: modelResourceName,
            withExtension: "glb"
        )

        if let modelURL {
            do {
                let model = try Entity.load(contentsOf: modelURL)
                model.name = "ChatAICompanionGLB"
                model.scale = SIMD3<Float>(repeating: 0.82)
                model.position = [0, -0.015, 0]
                scene.addChild(model)
                context.coordinator.head = model
                context.coordinator.assetLoaded = true
            } catch {
                context.coordinator.loadError = error.localizedDescription
            }
        } else {
            context.coordinator.loadError =
                "Missing model-1792924579279.glb. Ensure it is bundled in ChatAI/Resources/Companion."
        }

        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard let head = context.coordinator.head else { return }
        head.transform.rotation = simd_quatf(
            angle: headRotation,
            axis: [0, 1, 0]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var head: Entity?
        weak var view: ARView?
        var assetLoaded = false
        var loadError: String?
    }

    private func makeLight(
        color: UIColor,
        intensity: Float,
        position: SIMD3<Float>
    ) -> Entity {
        let light = Entity()
        var component = PointLightComponent()
        component.color = color
        component.intensity = intensity
        light.components.set(component)
        light.position = position
        return light
    }
}
