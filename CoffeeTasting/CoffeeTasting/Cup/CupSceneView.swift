import SceneKit
import SwiftUI
import UIKit

/// Lock-protected mailbox between the main thread (motion updates, SwiftUI) and SceneKit's
/// render thread, where the per-frame simulation runs.
final class CupSceneInputs: @unchecked Sendable {
    private let lock = NSLock()
    private var _gravity: Gravity = .upright
    private var _drinkFactor: Double = 0
    private var _refillRequested = false

    var gravity: Gravity {
        get { lock.lock(); defer { lock.unlock() }; return _gravity }
        set { lock.lock(); _gravity = newValue; lock.unlock() }
    }

    var drinkFactor: Double {
        get { lock.lock(); defer { lock.unlock() }; return _drinkFactor }
        set { lock.lock(); _drinkFactor = newValue; lock.unlock() }
    }

    func requestRefill() {
        lock.lock(); _refillRequested = true; lock.unlock()
    }

    func takeRefillRequest() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let value = _refillRequested
        _refillRequested = false
        return value
    }
}

/// The 3D mug. Transparent, so it composites over whatever sits behind it (the camera feed).
struct CupSceneView: UIViewRepresentable {
    /// Increment to pour a fresh cup (e.g. after saving a note).
    var refillTrigger: Int = 0
    var onCupTapped: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.cupScene.scene
        view.pointOfView = context.coordinator.cupScene.cameraNode
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onCupTapped = onCupTapped
        if context.coordinator.lastRefillTrigger != refillTrigger {
            context.coordinator.lastRefillTrigger = refillTrigger
            context.coordinator.inputs.requestRefill()
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let cupScene = CupScene()
        let inputs = CupSceneInputs()
        var onCupTapped: () -> Void = {}
        var lastRefillTrigger = 0

        private let motion = MotionManager()
        private var slosh = CoffeeSloshSimulator()
        private var drink = DrinkGestureDetector()
        private var fill = CupFillModel()
        private var lastTime: TimeInterval?
        private weak var view: SCNView?
        private var panRecognizer: UIPanGestureRecognizer?

        func attach(to view: SCNView) {
            self.view = view
            if motion.isAvailable {
                motion.start { [inputs] gravity in
                    inputs.gravity = gravity
                }
            } else {
                // Simulator / no motion hardware: drag the cup to tilt it, drag down to "drink".
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                view.addGestureRecognizer(pan)
                panRecognizer = pan
            }
        }

        func detach() {
            motion.stop()
            view?.delegate = nil
            view = nil
        }

        // MARK: Per-frame simulation (render thread)

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt: TimeInterval
            if let last = lastTime {
                dt = clamp(time - last, 0, 1.0 / 20.0)
            } else {
                dt = 1.0 / 60.0
            }
            lastTime = time

            if inputs.takeRefillRequest() {
                emit(fill.refill())
            }

            let gravity = inputs.gravity
            let drinkFactor = drink.update(gravity: gravity, dt: dt)
            emit(fill.update(drinkFactor: drinkFactor, dt: dt))

            let cupTip = Double(CupScene.maxDrinkTip) * drinkFactor
            slosh.step(gravity: gravity, extraTiltZ: cupTip, dt: dt)
            inputs.drinkFactor = drinkFactor

            cupScene.apply(fill: fill, slosh: slosh, drinkFactor: drinkFactor, time: time)
        }

        private func emit(_ event: CupFillModel.Event) {
            switch event {
            case .none:
                return
            case .sipStarted:
                DispatchQueue.main.async {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
                }
            case .becameEmpty:
                DispatchQueue.main.async {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                }
            case .refillStarted:
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            case .refillFinished:
                return
            }
        }

        // MARK: Gestures (main thread)

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view as? SCNView else { return }
            // A sip in progress should never open the dialog.
            guard inputs.drinkFactor < 0.3 else { return }
            let point = recognizer.location(in: view)
            let hits = view.hitTest(point, options: [.ignoreHiddenNodes: true, .boundingBoxOnly: false])
            guard hits.contains(where: { cupScene.isPartOfCup($0.node) }) else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            onCupTapped()
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                let translation = recognizer.translation(in: recognizer.view)
                let x = clamp(Double(translation.x) / 180, -1, 1)
                let z = clamp(Double(translation.y) / 180, -1, 1)
                let y = -sqrt(max(0, 1 - x * x - z * z))
                inputs.gravity = Gravity(x: x, y: y, z: z)
            case .ended, .cancelled, .failed:
                inputs.gravity = .upright
            default:
                break
            }
        }
    }
}
