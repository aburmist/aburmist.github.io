import SceneKit
import UIKit

/// Owns the SceneKit scene graph for the mug and knows how to pose it each frame.
///
/// Scene units are roughly decimetres. The cup sits on the origin with its rim at `rimHeight`.
/// Everything that belongs to the mug (body, handle, liquid, steam) hangs off `cupNode` so the
/// drinking animation can move the whole thing as one object.
final class CupScene {
    static let innerRadius: Float = 0.50
    static let outerRadius: Float = 0.55
    static let rimHeight: Float = 0.78
    static let floorTop: Float = 0.06
    static let liquidRadius: Float = 0.49
    /// Surface height when the cup is full. Leaves headroom below the rim for sloshing.
    static let fullSurfaceHeight: Float = 0.64
    /// How far the cup tips toward the viewer at full drink factor (radians).
    static let maxDrinkTip: Float = 35 * .pi / 180

    let scene = SCNScene()
    let cupNode = SCNNode()
    let liquidNode: SCNNode
    let liquidMaterial: SCNMaterial
    let steamNode = SCNNode()
    let denseSteam: SCNParticleSystem
    let wispSteam: SCNParticleSystem
    let cameraNode = SCNNode()

    private let denseSteamBaseRate: CGFloat = 36
    private let wispSteamBaseRate: CGFloat = 7

    static func surfaceHeight(fill: Double) -> Float {
        floorTop + Float(clamp(fill, 0, 1)) * (fullSurfaceHeight - floorTop)
    }

    init() {
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = CoffeeSurface.makeEnvironmentImage()
        scene.lightingEnvironment.intensity = 1.0

        // MARK: Materials
        let glaze = SCNMaterial()
        glaze.lightingModel = .physicallyBased
        glaze.diffuse.contents = UIColor(white: 0.96, alpha: 1)
        glaze.roughness.contents = 0.33
        glaze.metalness.contents = 0.0

        let innerGlaze = SCNMaterial()
        innerGlaze.lightingModel = .physicallyBased
        innerGlaze.diffuse.contents = UIColor(red: 0.93, green: 0.90, blue: 0.85, alpha: 1)
        innerGlaze.roughness.contents = 0.45
        innerGlaze.metalness.contents = 0.0

        let stain = SCNMaterial()
        stain.lightingModel = .physicallyBased
        stain.diffuse.contents = UIColor(red: 0.42, green: 0.29, blue: 0.18, alpha: 1)
        stain.roughness.contents = 0.6

        // MARK: Body
        let body = SCNTube(innerRadius: CGFloat(Self.innerRadius), outerRadius: CGFloat(Self.outerRadius), height: CGFloat(Self.rimHeight))
        body.radialSegmentCount = 96
        body.materials = [glaze, innerGlaze, glaze, glaze]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.name = "cup.body"
        bodyNode.position = SCNVector3(0, Self.rimHeight / 2, 0)
        cupNode.addChildNode(bodyNode)

        let floor = SCNCylinder(radius: CGFloat(Self.outerRadius), height: CGFloat(Self.floorTop))
        floor.radialSegmentCount = 96
        floor.materials = [glaze, stain, glaze]
        let floorNode = SCNNode(geometry: floor)
        floorNode.name = "cup.floor"
        floorNode.position = SCNVector3(0, Self.floorTop / 2, 0)
        cupNode.addChildNode(floorNode)

        let rim = SCNTorus(ringRadius: CGFloat((Self.innerRadius + Self.outerRadius) / 2), pipeRadius: CGFloat((Self.outerRadius - Self.innerRadius) / 2))
        rim.ringSegmentCount = 96
        rim.materials = [glaze]
        let rimNode = SCNNode(geometry: rim)
        rimNode.name = "cup.rim"
        rimNode.position = SCNVector3(0, Self.rimHeight, 0)
        cupNode.addChildNode(rimNode)

        let handle = SCNTorus(ringRadius: 0.20, pipeRadius: 0.05)
        handle.ringSegmentCount = 64
        handle.pipeSegmentCount = 32
        handle.materials = [glaze]
        let handleNode = SCNNode(geometry: handle)
        handleNode.name = "cup.handle"
        handleNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        handleNode.position = SCNVector3(Self.outerRadius + 0.13, 0.42, 0)
        cupNode.addChildNode(handleNode)

        // MARK: Liquid
        let liquidGeometry = CoffeeSurface.makeGeometry(radius: Self.liquidRadius)
        let liquid = SCNMaterial()
        liquid.lightingModel = .physicallyBased
        liquid.diffuse.contents = CoffeeSurface.makeCremaTexture()
        liquid.roughness.contents = 0.12
        liquid.metalness.contents = 0.0
        liquid.isDoubleSided = false
        liquid.shaderModifiers = [.geometry: CoffeeSurface.geometryShader]
        liquid.setValue(NSNumber(value: Self.liquidRadius), forKey: "radius")
        liquid.setValue(NSNumber(value: Float(0)), forKey: "slopeX")
        liquid.setValue(NSNumber(value: Float(0)), forKey: "slopeZ")
        liquid.setValue(NSNumber(value: Float(0)), forKey: "rippleAmp")
        liquid.setValue(NSNumber(value: Float(0)), forKey: "time")
        liquidGeometry.materials = [liquid]
        liquidMaterial = liquid
        liquidNode = SCNNode(geometry: liquidGeometry)
        liquidNode.name = "cup.liquid"
        liquidNode.position = SCNVector3(0, Self.fullSurfaceHeight, 0)
        cupNode.addChildNode(liquidNode)

        // MARK: Steam
        let sprite = CoffeeSurface.makeSteamSprite()
        denseSteam = Self.makeSteam(dense: true, sprite: sprite)
        wispSteam = Self.makeSteam(dense: false, sprite: sprite)
        steamNode.name = "cup.steam"
        steamNode.position = SCNVector3(0, Self.fullSurfaceHeight + 0.02, 0)
        steamNode.addParticleSystem(denseSteam)
        let wispNode = SCNNode()
        wispNode.position = SCNVector3(0, 0.25, 0)
        wispNode.addParticleSystem(wispSteam)
        steamNode.addChildNode(wispNode)
        cupNode.addChildNode(steamNode)

        cupNode.name = "cup"
        scene.rootNode.addChildNode(cupNode)

        // MARK: Shadow
        let shadowPlane = SCNPlane(width: 1.9, height: 1.9)
        let shadowMaterial = SCNMaterial()
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = CoffeeSurface.makeShadowTexture()
        shadowMaterial.isDoubleSided = true
        shadowMaterial.writesToDepthBuffer = false
        shadowMaterial.blendMode = .alpha
        shadowPlane.materials = [shadowMaterial]
        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.name = "shadow"
        shadowNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        shadowNode.position = SCNVector3(0.08, 0.001, 0.05)
        shadowNode.renderingOrder = -10
        scene.rootNode.addChildNode(shadowNode)

        // MARK: Camera & lights
        let camera = SCNCamera()
        camera.fieldOfView = 38
        camera.zNear = 0.05
        camera.zFar = 20
        camera.wantsHDR = false
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.15, 2.55)
        cameraNode.look(at: SCNVector3(0, 0.40, 0))
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 320
        ambient.color = UIColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 950
        key.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        key.castsShadow = false
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-55 * Float.pi / 180, -35 * Float.pi / 180, 0)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 260
        fill.color = UIColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(1.6, 1.2, 1.4)
        scene.rootNode.addChildNode(fillNode)
    }

    private static func makeSteam(dense: Bool, sprite: UIImage) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = sprite
        p.emitterShape = SCNCylinder(radius: dense ? 0.30 : 0.22, height: 0.02)
        p.birthLocation = .volume
        p.birthRate = dense ? 36 : 7
        p.particleLifeSpan = dense ? 2.6 : 4.5
        p.particleLifeSpanVariation = dense ? 0.8 : 1.2
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = dense ? 12 : 22
        p.particleVelocity = dense ? 0.32 : 0.45
        p.particleVelocityVariation = 0.12
        p.particleSize = dense ? 0.22 : 0.34
        p.particleSizeVariation = 0.08
        p.particleColor = UIColor(white: 1, alpha: dense ? 0.30 : 0.16)
        p.particleColorVariation = SCNVector4(0, 0, 0, 0.06)
        p.particleAngleVariation = 180
        p.particleAngularVelocity = dense ? 25 : 45
        p.particleAngularVelocityVariation = 20
        p.isAffectedByGravity = false
        p.acceleration = SCNVector3(0, 0.08, 0)
        p.dampingFactor = 0.35
        p.blendMode = .alpha
        p.isLightingEnabled = false
        p.sortingMode = .distance
        p.orientationMode = .billboardScreenAligned
        p.isLocal = false
        p.loops = true

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 1.0, 0.7, 0.0]
        opacity.keyTimes = [0, 0.25, 0.6, 1]
        let size = CAKeyframeAnimation(keyPath: "size")
        let sizes: [Double] = dense ? [0.12, 0.22, 0.42] : [0.20, 0.34, 0.62]
        size.values = sizes
        size.keyTimes = [0, 0.3, 1]
        p.propertyControllers = [
            .opacity: SCNParticlePropertyController(animation: opacity),
            .size: SCNParticlePropertyController(animation: size),
        ]
        return p
    }

    /// Poses the cup, liquid and steam for the current frame. Call from the renderer delegate.
    func apply(fill: CupFillModel, slosh: CoffeeSloshSimulator, drinkFactor: Double, time: TimeInterval) {
        let f = Float(clamp(drinkFactor, 0, 1))

        // Bring the mug up toward the viewer and tip its near rim down, like raising it to drink.
        let scale = 1 + 0.35 * f
        cupNode.scale = SCNVector3(scale, scale, scale)
        cupNode.position = SCNVector3(0, 0.28 * f, 0.55 * f)
        cupNode.eulerAngles = SCNVector3(Self.maxDrinkTip * f, 0, 0)

        // Liquid height follows the fill level.
        let surfaceY = Self.surfaceHeight(fill: fill.fillLevel)
        liquidNode.isHidden = fill.isEmpty
        liquidNode.position = SCNVector3(0, surfaceY, 0)

        // Slopes, limited so the liquid neither climbs far above the rim nor dips below the floor.
        let r = Self.liquidRadius
        let headroomUp = max(0.01, Self.rimHeight + 0.03 - surfaceY)
        let headroomDown = max(0.01, surfaceY - Self.floorTop - 0.01)
        var slopeX = Float(tan(slosh.tiltX))
        var slopeZ = Float(tan(slosh.tiltZ))
        let rise = (abs(slopeX) + max(slopeZ, 0)) * r
        if rise > headroomUp {
            let k = headroomUp / rise
            slopeX *= k
            if slopeZ > 0 { slopeZ *= k }
        }
        let drop = (abs(slopeX) + max(-slopeZ, 0)) * r
        if drop > headroomDown {
            let k = headroomDown / drop
            slopeX *= k
            if slopeZ < 0 { slopeZ *= k }
        }

        let ripple = Float(0.006 * slosh.energy + 0.0012 * Double(f))
        liquidMaterial.setValue(NSNumber(value: slopeX), forKey: "slopeX")
        liquidMaterial.setValue(NSNumber(value: slopeZ), forKey: "slopeZ")
        liquidMaterial.setValue(NSNumber(value: ripple), forKey: "rippleAmp")
        liquidMaterial.setValue(NSNumber(value: Float(time.truncatingRemainder(dividingBy: 1000))), forKey: "time")

        // Steam rises from the surface and leans toward the viewer while drinking.
        steamNode.position = SCNVector3(0, surfaceY + 0.02, 0)
        let intensity = CGFloat(fill.steamIntensity)
        denseSteam.birthRate = denseSteamBaseRate * intensity * (1 + 0.6 * CGFloat(f))
        wispSteam.birthRate = wispSteamBaseRate * intensity
        denseSteam.acceleration = SCNVector3(0, 0.08, 0.55 * f)
        wispSteam.acceleration = SCNVector3(0, 0.08, 0.45 * f)
    }

    func isPartOfCup(_ node: SCNNode) -> Bool {
        var current: SCNNode? = node
        while let n = current {
            if n === cupNode { return true }
            current = n.parent
        }
        return false
    }
}
