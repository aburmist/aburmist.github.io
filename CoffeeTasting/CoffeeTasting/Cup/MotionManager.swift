import CoreMotion
import Foundation

/// Thin wrapper around CoreMotion that delivers the gravity vector at 60 Hz.
/// Updates arrive on a private queue; the callback must be thread-safe.
final class MotionManager {
    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.aburmist.CoffeeTasting.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start(onUpdate: @escaping (Gravity) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { motion, _ in
            guard let motion else { return }
            onUpdate(Gravity(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
