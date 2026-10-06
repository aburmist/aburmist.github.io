import Foundation

/// Spring-damped model of how the coffee surface tilts relative to the cup.
///
/// The surface is described by two slopes: `tiltX` is the angle by which the liquid rises toward
/// the +x (right) wall of the cup, `tiltZ` the angle by which it rises toward the +z (near, viewer)
/// wall. Liquid stays level in the real world, so relative to a cup that is rigidly attached to the
/// phone it rises on whichever side gravity points toward. The spring is deliberately underdamped
/// so a sudden tilt overshoots and wobbles before settling.
struct CoffeeSloshSimulator: Equatable {
    /// Spring stiffness (1/s²). Higher = snappier liquid.
    var stiffness: Double = 40
    /// Damping (1/s). Critical damping is `2 * sqrt(stiffness)`; lower values wobble.
    var damping: Double = 4
    /// Largest tilt the liquid is allowed to reach, in radians.
    var maxTilt: Double = 22 * .pi / 180

    private(set) var tiltX: Double = 0
    private(set) var tiltZ: Double = 0
    private(set) var velocityX: Double = 0
    private(set) var velocityZ: Double = 0

    /// 0 when the surface is still, approaching 1 while it is moving fast. Drives ripple amplitude.
    var energy: Double {
        clamp((abs(velocityX) + abs(velocityZ)) / 1.5, 0, 1)
    }

    /// Target slopes for a given gravity vector, before clamping.
    static func targetTilt(for gravity: Gravity) -> (tiltX: Double, tiltZ: Double) {
        let g = gravity.normalized
        // `-g.y` is the component of gravity along the cup's "down" axis. When the phone is
        // upright this is 1 and both angles are 0.
        let down = max(-g.y, 0.05)
        return (atan2(g.x, down), atan2(g.z, down))
    }

    /// Advances the simulation by `dt` seconds toward the level implied by `gravity`.
    /// `extraTiltZ` is added to the near-side target, used when the virtual cup itself is tipped
    /// toward the viewer during the drinking animation.
    mutating func step(gravity: Gravity, extraTiltZ: Double = 0, dt: TimeInterval) {
        guard dt > 0, dt.isFinite else { return }
        let target = Self.targetTilt(for: gravity)
        let targetX = clamp(target.tiltX, -maxTilt, maxTilt)
        let targetZ = clamp(target.tiltZ + extraTiltZ, -maxTilt * 1.6, maxTilt * 1.6)

        // Semi-implicit Euler keeps the spring stable at 60 Hz with these constants.
        let accelX = stiffness * (targetX - tiltX) - damping * velocityX
        let accelZ = stiffness * (targetZ - tiltZ) - damping * velocityZ
        velocityX += accelX * dt
        velocityZ += accelZ * dt
        tiltX += velocityX * dt
        tiltZ += velocityZ * dt

        // Never let numeric drift push the liquid through the cup walls.
        tiltX = clamp(tiltX, -maxTilt * 1.2, maxTilt * 1.2)
        tiltZ = clamp(tiltZ, -maxTilt * 1.2, maxTilt * 2)
    }

    mutating func reset() {
        tiltX = 0; tiltZ = 0; velocityX = 0; velocityZ = 0
    }
}
