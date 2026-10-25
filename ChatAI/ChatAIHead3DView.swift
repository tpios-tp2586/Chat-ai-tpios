import SwiftUI
import RealityKit
import UIKit

struct ChatAIHead3DView: UIViewRepresentable {
    var headRotation: Float = 0
    var speaking: Bool = false

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.cameraMode = .nonAR
        view.environment.background = .color(
            UIColor(red: 0.025, green: 0.04, blue: 0.075, alpha: 1)
        )

        let scene = AnchorEntity(world: .zero)
        let head = makeHead()
        scene.addChild(head)
        view.scene.addAnchor(scene)

        let camera = PerspectiveCamera()
        camera.position = [0, 0.05, 1.25]
        camera.look(
            at: [0, 0.02, 0],
            from: camera.position,
            relativeTo: nil
        )
        scene.addChild(camera)

        let keyLight = makeLight(
            color: .white,
            intensity: 1300,
            position: [-0.45, 0.55, 0.65]
        )
        scene.addChild(keyLight)

        let fillLight = makeLight(
            color: UIColor(red: 0.25, green: 0.7, blue: 1, alpha: 1),
            intensity: 800,
            position: [0.5, 0.15, 0.4]
        )
        scene.addChild(fillLight)

        let rimLight = makeLight(
            color: .white,
            intensity: 1000,
            position: [0, 0.45, -0.4]
        )
        scene.addChild(rimLight)

        context.coordinator.head = head
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

    private func material(
        _ color: UIColor,
        metallic: Float = 0,
        roughness: Float = 0.45
    ) -> PhysicallyBasedMaterial {
        var result = PhysicallyBasedMaterial()
        result.baseColor = .init(tint: color)
        result.metallic = metallic
        result.roughness = roughness
        return result
    }

    private func ball(
        _ name: String,
        _ size: SIMD3<Float>,
        _ position: SIMD3<Float>,
        _ color: UIColor,
        metallic: Float = 0,
        roughness: Float = 0.45
    ) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 1)
        let model = ModelEntity(
            mesh: mesh,
            materials: [
                material(color, metallic: metallic, roughness: roughness)
            ]
        )
        model.name = name
        model.scale = size
        model.position = position
        return model
    }

    private func makeHead() -> Entity {
        let root = Entity()

        let skin = UIColor(
            red: 0.86, green: 0.66, blue: 0.55, alpha: 1
        )
        let skinLight = UIColor(
            red: 0.96, green: 0.77, blue: 0.66, alpha: 1
        )
        let hair = UIColor(
            red: 0.075, green: 0.045, blue: 0.055, alpha: 1
        )
        let whiteMetal = UIColor(
            red: 0.72, green: 0.79, blue: 0.85, alpha: 1
        )
        let cyan = UIColor(
            red: 0.05, green: 0.78, blue: 1, alpha: 1
        )
        let dark = UIColor(
            red: 0.025, green: 0.035, blue: 0.055, alpha: 1
        )

        // Neck: mechanical assembly
        root.addChild(ball(
            "MechanicalNeck",
            [0.19, 0.25, 0.16],
            [0, -0.48, 0],
            whiteMetal,
            metallic: 0.85,
            roughness: 0.25
        ))

        // Collar
        root.addChild(ball(
            "MetalCollar",
            [0.29, 0.075, 0.23],
            [0, -0.59, 0],
            whiteMetal,
            metallic: 0.9,
            roughness: 0.2
        ))

        // Glowing collar ring
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.018, radius: 0.235),
            materials: [SimpleMaterial(
                color: cyan,
                roughness: 0.2,
                isMetallic: true
            )]
        )
        ring.name = "CyanPowerRing"
        ring.position = [0, -0.55, 0]
        root.addChild(ring)

        // Face base and jaw
        root.addChild(ball(
            "Face",
            [0.265, 0.355, 0.205],
            [0, 0.02, 0],
            skin
        ))

        root.addChild(ball(
            "Jaw",
            [0.205, 0.19, 0.17],
            [0, -0.17, 0.035],
            skin
        ))

        root.addChild(ball(
            "Chin",
            [0.105, 0.07, 0.11],
            [0, -0.245, 0.075],
            skinLight
        ))

        // Hair cap
        root.addChild(ball(
            "HairCap",
            [0.278, 0.30, 0.22],
            [0, 0.17, -0.035],
            hair
        ))

        // Forehead skin layer in front of hair
        root.addChild(ball(
            "Forehead",
            [0.205, 0.13, 0.045],
            [0, 0.13, 0.157],
            skinLight
        ))

        // Hair locks framing the face
        root.addChild(ball(
            "LeftHairLock",
            [0.055, 0.25, 0.07],
            [-0.225, 0.025, 0.10],
            hair
        ))

        root.addChild(ball(
            "RightHairLock",
            [0.055, 0.25, 0.07],
            [0.225, 0.025, 0.10],
            hair
        ))

        // Ears
        root.addChild(ball(
            "LeftEar",
            [0.055, 0.085, 0.04],
            [-0.26, -0.015, 0.015],
            skin
        ))

        root.addChild(ball(
            "RightEar",
            [0.055, 0.085, 0.04],
            [0.26, -0.015, 0.015],
            skin
        ))

        // Eye sockets
        for side: Float in [-1, 1] {
            root.addChild(ball(
                side < 0 ? "LeftEyeSocket" : "RightEyeSocket",
                [0.083, 0.047, 0.035],
                [side * 0.105, 0.055, 0.179],
                UIColor(red: 0.22, green: 0.13, blue: 0.12, alpha: 1)
            ))

            root.addChild(ball(
                side < 0 ? "LeftEye" : "RightEye",
                [0.064, 0.032, 0.025],
                [side * 0.105, 0.055, 0.205],
                .white
            ))

            root.addChild(ball(
                side < 0 ? "LeftIris" : "RightIris",
                [0.026, 0.027, 0.012],
                [side * 0.105, 0.055, 0.229],
                UIColor(red: 0.25, green: 0.55, blue: 0.62, alpha: 1)
            ))

            root.addChild(ball(
                side < 0 ? "LeftPupil" : "RightPupil",
                [0.012, 0.018, 0.008],
                [side * 0.105, 0.055, 0.239],
                dark
            ))

            root.addChild(ball(
                side < 0 ? "LeftBrow" : "RightBrow",
                [0.075, 0.014, 0.018],
                [side * 0.105, 0.108, 0.195],
                hair
            ))
        }

        // Nose bridge and tip
        root.addChild(ball(
            "NoseBridge",
            [0.035, 0.085, 0.035],
            [0, -0.005, 0.205],
            skinLight
        ))

        root.addChild(ball(
            "NoseTip",
            [0.045, 0.03, 0.035],
            [0, -0.055, 0.222],
            skin
        ))

        // Lips
        root.addChild(ball(
            "UpperLip",
            [0.067, 0.018, 0.022],
            [0, -0.125, 0.205],
            UIColor(red: 0.48, green: 0.16, blue: 0.19, alpha: 1)
        ))

        root.addChild(ball(
            "LowerLip",
            [0.057, 0.015, 0.018],
            [0, -0.147, 0.207],
            UIColor(red: 0.72, green: 0.28, blue: 0.32, alpha: 1)
        ))

        // Small temple hardware
        for side: Float in [-1, 1] {
            root.addChild(ball(
                "TempleConnector",
                [0.025, 0.055, 0.025],
                [side * 0.267, 0.06, 0.015],
                cyan,
                metallic: 0.75
            ))
        }

        return root
    }
}