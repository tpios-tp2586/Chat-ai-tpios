/// SceneKit-based 3D chibi companion stage.
/// Drop this struct in place of the existing Companion3DStage in CompanionChatView.swift.
/// Node names used by updateUIView are preserved: companionRoot, head, irisL, irisR, mouth, environmentGlow.
private struct Companion3DStage: UIViewRepresentable {
    let emotion: String
    let isNight: Bool
    let isSpeaking: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = makeScene()
        view.backgroundColor = .clear
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let scene = view.scene,
              let character = scene.rootNode.childNode(withName: "companionRoot", recursively: true) else { return }

        let head = character.childNode(withName: "head", recursively: true)
        head?.eulerAngles.z = emotion == "shy"     ?  0.14 : (emotion == "thinking" ? -0.11 : 0)
        head?.eulerAngles.y = emotion == "thinking" ? -0.13 : 0

        let mouth = character.childNode(withName: "mouth", recursively: true)
        mouth?.scale.y = isSpeaking ? 3.0 : (emotion == "surprised" ? 2.4 : (emotion == "happy" ? 1.6 : 1.0))
        mouth?.scale.x = emotion == "happy" ? 1.7 : (emotion == "surprised" ? 1.3 : 1.0)

        for suffix in ["L", "R"] {
            character.childNode(withName: "iris" + suffix, recursively: true)?.position.x =
                Float(suffix == "L" ? -0.30 : 0.30) + Float(emotion == "thinking" ? -0.048 : 0)
        }

        scene.background.contents = UIColor.clear
        scene.rootNode.childNode(withName: "environmentGlow", recursively: true)?
            .geometry?.firstMaterial?.diffuse.contents =
            isNight
            ? UIColor(red: 0.34, green: 0.42, blue: 0.95, alpha: 0.26)
            : UIColor(red: 1.00, green: 0.68, blue: 0.46, alpha: 0.22)
    }

    // MARK: - Scene construction

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = UIColor(white: 0.82, alpha: 1)

        // Camera
        let cam = SCNCamera()
        cam.fieldOfView = 32
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 1.72, 7.6)
        camNode.look(at: SCNVector3(0, 1.52, 0))
        scene.rootNode.addChildNode(camNode)

        // Key light (warm, front-left)
        addLight(to: scene, type: .directional,
                 color: UIColor(red: 1.0, green: 0.95, blue: 0.90, alpha: 1),
                 intensity: 920,
                 position: SCNVector3(-3, 6, 5),
                 lookAt: SCNVector3(0, 1.5, 0))

        // Fill light (right)
        addLight(to: scene, type: .omni,
                 color: UIColor(red: 0.90, green: 0.90, blue: 1.0, alpha: 1),
                 intensity: 380,
                 position: SCNVector3(3, 2, 3))

        // Rim light (cyan, behind character — gives anime depth)
        addLight(to: scene, type: .omni,
                 color: UIColor(red: 0.38, green: 0.72, blue: 1.0, alpha: 1),
                 intensity: 680,
                 position: SCNVector3(0, 3.5, -4.5))

        // Ambient
        addLight(to: scene, type: .ambient,
                 color: UIColor(red: 0.78, green: 0.78, blue: 1.0, alpha: 1),
                 intensity: 220,
                 position: SCNVector3(0, 0, 0))

        // Load real USDZ if available
        if let modelURL = Bundle.main.url(forResource: "CompanionChibi", withExtension: "usdz"),
           let imported = try? SCNScene(url: modelURL, options: nil) {
            let importedRoot = SCNNode()
            importedRoot.name = "companionRoot"
            for child in imported.rootNode.childNodes {
                importedRoot.addChildNode(child.clone())
            }
            let b = importedRoot.boundingBox
            let h = max(b.max.y - b.min.y, 0.001)
            let s = Float(2.8) / h
            importedRoot.scale    = SCNVector3(s, s, s)
            importedRoot.position.y = -((b.min.y + b.max.y) * 0.5) * s + 1.4
            scene.rootNode.addChildNode(importedRoot)
            return scene
        }

        // ── Procedural character ──────────────────────────────────────────
        let root = SCNNode()
        root.name = "companionRoot"
        scene.rootNode.addChildNode(root)

        // Materials
        let mSkin   = pbr(UIColor(red: 1.00, green: 0.83, blue: 0.74, alpha: 1), r: 0.50)
        let mHair   = pbr(UIColor(red: 0.08, green: 0.05, blue: 0.15, alpha: 1), r: 0.22)
        let mHairHi = pbr(UIColor(red: 0.30, green: 0.18, blue: 0.46, alpha: 1), r: 0.20)
        let mDress  = pbr(UIColor(red: 0.44, green: 0.32, blue: 0.84, alpha: 1), r: 0.55)
        let mSkirt  = pbr(UIColor(red: 0.52, green: 0.38, blue: 0.90, alpha: 1), r: 0.50)
        let mWhite  = pbr(.white, r: 0.45)
        let mIris   = pbr(UIColor(red: 0.42, green: 0.26, blue: 0.82, alpha: 1), r: 0.12,
                          emit: UIColor(red: 0.18, green: 0.08, blue: 0.48, alpha: 0.35))
        let mBlack  = pbr(UIColor(red: 0.08, green: 0.05, blue: 0.10, alpha: 1), r: 0.30)
        let mPink   = pbr(UIColor(red: 1.00, green: 0.36, blue: 0.62, alpha: 1), r: 0.50)
        let mBlush  = pbr(UIColor(red: 1.00, green: 0.56, blue: 0.68, alpha: 0.65), r: 0.80)
        let mNose   = pbr(UIColor(red: 0.97, green: 0.73, blue: 0.68, alpha: 1), r: 0.60)
        let mSock   = pbr(UIColor(red: 0.96, green: 0.95, blue: 0.99, alpha: 1), r: 0.55)
        let mShoe   = pbr(UIColor(red: 0.14, green: 0.09, blue: 0.22, alpha: 1), r: 0.35)

        // ── Body ─────────────────────────────────────────────────────────
        sph(root, "body",   r: 0.56, p: SCNVector3(0, 0.98, 0),  m: mDress,  s: SCNVector3(1.00, 1.10, 0.72))

        // Skirt cone (wider bottom)
        let skirtGeo = SCNCone(topRadius: 0.44, bottomRadius: 0.72, height: 0.58)
        skirtGeo.radialSegmentCount = 32; skirtGeo.firstMaterial = mSkirt
        let skirtNode = SCNNode(geometry: skirtGeo)
        skirtNode.name = "skirt"; skirtNode.position = SCNVector3(0, 0.50, 0)
        root.addChildNode(skirtNode)

        // Collar
        sph(root, "collar", r: 0.15, p: SCNVector3(0, 1.28, 0.20), m: mWhite, s: SCNVector3(1.9, 0.38, 0.75))

        // Neck
        cap(root, "neck", cr: 0.112, h: 0.22, p: SCNVector3(0, 1.38, 0), m: mSkin)

        // ── Head ─────────────────────────────────────────────────────────
        let head = sph(root, "head", r: 0.69, p: SCNVector3(0, 2.10, 0), m: mSkin, s: SCNVector3(0.93, 1.00, 0.80))

        // ── Hair ─────────────────────────────────────────────────────────
        let backHair = sph(root, "backHair", r: 0.75, p: SCNVector3(0, 2.20, -0.15), m: mHair, s: SCNVector3(1.08, 1.10, 0.92))
        backHair.renderingOrder = -1
        sph(root, "fringe",  r: 0.50, p: SCNVector3(0, 2.60, 0.37),  m: mHair, s: SCNVector3(1.38, 0.42, 0.50))
        sph(root, "bangL",   r: 0.21, p: SCNVector3(-0.54, 2.40, 0.30), m: mHair, s: SCNVector3(0.68, 1.45, 0.58))
        sph(root, "bangR",   r: 0.21, p: SCNVector3( 0.54, 2.40, 0.30), m: mHair, s: SCNVector3(0.68, 1.45, 0.58))
        // Twin tails
        cap(root, "leftLock",  cr: 0.125, h: 1.00, p: SCNVector3(-0.74, 1.70, 0.04), m: mHair,
            euler: SCNVector3(0.08, 0, 0.16))
        cap(root, "rightLock", cr: 0.125, h: 1.00, p: SCNVector3( 0.74, 1.70, 0.04), m: mHair,
            euler: SCNVector3(0.08, 0, -0.16))
        sph(root, "hairShine", r: 0.055, p: SCNVector3(-0.28, 2.76, 0.70), m: mHairHi, s: SCNVector3(2.5, 0.48, 0.38))

        // ── Eyes ─────────────────────────────────────────────────────────
        for (x, sfx) in [(-Float(0.30), "L"), (Float(0.30), "R")] {
            let ew = sph(root, "eyeWhite\(sfx)", r: 0.182,
                         p: SCNVector3(x, 2.14, 0.635), m: mWhite, s: SCNVector3(0.86, 1.16, 0.27))
            let ei = sph(root, "iris\(sfx)", r: 0.126,
                         p: SCNVector3(x, 2.12, 0.698), m: mIris,  s: SCNVector3(0.86, 1.20, 0.27))
            sph(root, "pupil\(sfx)", r: 0.060,
                p: SCNVector3(x, 2.125, 0.730), m: mBlack, s: SCNVector3(0.82, 1.24, 0.27))
            sph(root, "sparkle1\(sfx)", r: 0.026, p: SCNVector3(x - 0.028, 2.162, 0.744), m: mWhite)
            sph(root, "sparkle2\(sfx)", r: 0.014, p: SCNVector3(x + 0.046, 2.090, 0.744), m: mWhite)

            // Eyelash — thin box across top of eye
            let lashGeo = SCNBox(width: CGFloat(0.36), height: 0.030, length: 0.038, chamferRadius: 0.008)
            lashGeo.firstMaterial = mBlack
            let lash = SCNNode(geometry: lashGeo)
            lash.name = "lash\(sfx)"; lash.position = SCNVector3(x, 2.202, 0.672)
            root.addChildNode(lash)

            // Eyebrow — slight arch toward outer edge
            let browGeo = SCNBox(width: CGFloat(0.26), height: 0.022, length: 0.036, chamferRadius: 0.006)
            browGeo.firstMaterial = mHair
            let brow = SCNNode(geometry: browGeo)
            brow.name = "brow\(sfx)"; brow.position = SCNVector3(x, 2.302, 0.648)
            brow.eulerAngles.z = sfx == "L" ?  0.10 : -0.10
            root.addChildNode(brow)

            // Blink
            let blinkWait = Double.random(in: 2.6...3.8)
            let blinkSeq = SCNAction.repeatForever(.sequence([
                .wait(duration: blinkWait),
                .customAction(duration: 0.07) { n, _ in n.scale.y = 0.07 },
                .customAction(duration: 0.10) { n, _ in n.scale.y = 1.16 }
            ]))
            ew.runAction(blinkSeq, forKey: "blink")
            ei.runAction(.repeatForever(.sequence([
                .wait(duration: blinkWait),
                .customAction(duration: 0.07) { n, _ in n.scale.y = 0.07 },
                .customAction(duration: 0.10) { n, _ in n.scale.y = 1.20 }
            ])), forKey: "blink")
        }

        // Blush
        sph(root, "blushL", r: 0.090, p: SCNVector3(-0.50, 1.96, 0.612), m: mBlush, s: SCNVector3(1.45, 0.40, 0.22))
        sph(root, "blushR", r: 0.090, p: SCNVector3( 0.50, 1.96, 0.612), m: mBlush, s: SCNVector3(1.45, 0.40, 0.22))

        // Nose hint
        sph(root, "nose",  r: 0.026, p: SCNVector3(0, 2.02, 0.698), m: mNose)

        // Mouth
        sph(root, "mouth", r: 0.046, p: SCNVector3(0, 1.89, 0.692), m: mBlack, s: SCNVector3(1.15, 0.58, 0.22))

        // ── Hair accessory — bow ─────────────────────────────────────────
        sph(root, "bowWingL", r: 0.125, p: SCNVector3(-0.66, 2.74, 0.14), m: mPink, s: SCNVector3(1.30, 0.60, 0.46))
        sph(root, "bowWingR", r: 0.125, p: SCNVector3(-0.84, 2.74, 0.14), m: mPink, s: SCNVector3(1.30, 0.60, 0.46))
        sph(root, "bowKnot",  r: 0.062, p: SCNVector3(-0.75, 2.74, 0.20), m: mWhite)

        // ── Arms ─────────────────────────────────────────────────────────
        let leftArm = cap(root, "leftArm",  cr: 0.108, h: 0.66,
                          p: SCNVector3(-0.64, 0.98, 0.02), m: mDress,
                          euler: SCNVector3(0, 0, -0.40))
        let rightArm = cap(root, "rightArm", cr: 0.108, h: 0.66,
                           p: SCNVector3( 0.64, 0.98, 0.02), m: mDress,
                           euler: SCNVector3(0, 0,  0.40))
        // Hands
        sph(root, "handL", r: 0.115, p: SCNVector3(-0.90, 0.67, 0.02), m: mSkin, s: SCNVector3(0.90, 0.84, 0.74))
        sph(root, "handR", r: 0.115, p: SCNVector3( 0.90, 0.67, 0.02), m: mSkin, s: SCNVector3(0.90, 0.84, 0.74))

        // ── Legs ─────────────────────────────────────────────────────────
        cap(root, "leftLeg",  cr: 0.122, h: 0.54, p: SCNVector3(-0.21, 0.06, 0.02), m: mSkin)
        cap(root, "rightLeg", cr: 0.122, h: 0.54, p: SCNVector3( 0.21, 0.06, 0.02), m: mSkin)
        cap(root, "leftSock",  cr: 0.130, h: 0.22, p: SCNVector3(-0.21, -0.23, 0.02), m: mSock)
        cap(root, "rightSock", cr: 0.130, h: 0.22, p: SCNVector3( 0.21, -0.23, 0.02), m: mSock)
        // Shoes — elongated sphere for chibi style
        sph(root, "shoeL", r: 0.140, p: SCNVector3(-0.21, -0.38, 0.05), m: mShoe, s: SCNVector3(0.86, 0.60, 1.28))
        sph(root, "shoeR", r: 0.140, p: SCNVector3( 0.21, -0.38, 0.05), m: mShoe, s: SCNVector3(0.86, 0.60, 1.28))

        // ── Environment glow disc ─────────────────────────────────────────
        let glowGeo = SCNSphere(radius: 1.62)
        glowGeo.firstMaterial = pbr(UIColor(red: 0.54, green: 0.62, blue: 1.0, alpha: 0.13))
        glowGeo.firstMaterial?.isDoubleSided = true
        let glowNode = SCNNode(geometry: glowGeo)
        glowNode.name = "environmentGlow"
        glowNode.position = SCNVector3(0, 1.60, -1.05)
        glowNode.scale = SCNVector3(1.08, 1.22, 0.11)
        root.addChildNode(glowNode)

        // Drop shadow under feet
        let shadowGeo = SCNPlane(width: 0.88, height: 0.36)
        let shadowMat = SCNMaterial()
        shadowMat.diffuse.contents = UIColor(white: 0, alpha: 0.25)
        shadowMat.isDoubleSided = true
        shadowGeo.firstMaterial = shadowMat
        let shadowNode = SCNNode(geometry: shadowGeo)
        shadowNode.name = "shadow"
        shadowNode.position = SCNVector3(0, -0.49, 0.06)
        shadowNode.eulerAngles.x = -.pi / 2
        root.addChildNode(shadowNode)

        // ── Animations ───────────────────────────────────────────────────
        // Breathing (whole root scales)
        root.runAction(.repeatForever(.sequence([
            .scale(to: 1.022, duration: 2.0),
            .scale(to: 1.000, duration: 2.0)
        ])), forKey: "breathing")

        // Float up/down
        root.runAction(.repeatForever(.sequence([
            .moveBy(x: 0, y: 0.045, z: 0, duration: 1.9),
            .moveBy(x: 0, y: -0.045, z: 0, duration: 1.9)
        ])), forKey: "float")

        // Head idle tilt
        head.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z:  0.032, duration: 1.9),
            .rotateTo(x: 0, y: 0, z: -0.032, duration: 1.9)
        ])), forKey: "headIdle")

        // Arm sway
        leftArm.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: -0.30, duration: 1.4),
            .rotateTo(x: 0, y: 0, z: -0.48, duration: 1.4)
        ])), forKey: "armSwayL")
        rightArm.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: 0.48, duration: 1.4),
            .rotateTo(x: 0, y: 0, z: 0.30, duration: 1.4)
        ])), forKey: "armSwayR")

        return scene
    }

    // MARK: - Helpers

    @discardableResult
    private func sph(_ parent: SCNNode, _ name: String, r: CGFloat,
                     p: SCNVector3, m: SCNMaterial, s: SCNVector3 = SCNVector3(1,1,1)) -> SCNNode {
        let geo = SCNSphere(radius: r); geo.segmentCount = 32; geo.firstMaterial = m
        let node = SCNNode(geometry: geo); node.name = name; node.position = p; node.scale = s
        parent.addChildNode(node); return node
    }

    @discardableResult
    private func cap(_ parent: SCNNode, _ name: String, cr: CGFloat, h: CGFloat,
                     p: SCNVector3, m: SCNMaterial, euler: SCNVector3 = .init(0,0,0)) -> SCNNode {
        let geo = SCNCapsule(capRadius: cr, height: h); geo.segmentCount = 24; geo.firstMaterial = m
        let node = SCNNode(geometry: geo); node.name = name; node.position = p; node.eulerAngles = euler
        parent.addChildNode(node); return node
    }

    private func pbr(_ color: UIColor, r: CGFloat = 0.50, metallic: CGFloat = 0,
                     emit: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = r
        m.metalness.contents = metallic
        if let e = emit { m.emission.contents = e }
        return m
    }

    @discardableResult
    private func addLight(to scene: SCNScene, type: SCNLight.LightType,
                          color: UIColor, intensity: CGFloat,
                          position: SCNVector3, lookAt: SCNVector3? = nil) -> SCNNode {
        let light = SCNLight(); light.type = type; light.color = color; light.intensity = intensity
        let node = SCNNode(); node.light = light; node.position = position
        if let t = lookAt { node.look(at: t) }
        scene.rootNode.addChildNode(node); return node
    }
}