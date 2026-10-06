import Foundation

/// Turns the gravity vector into a smooth "how far into a sip are we" factor.
///
/// Holding the phone upright and tipping its top edge toward your face (the way you would bring a
/// mug to your lips) makes the screen face downward, so gravity's `z` component becomes positive.
/// That component is the drinking signal. Rolling the phone sideways is ignored so a casual tilt
/// never looks like a sip, and hysteresis plus a low-pass filter stop hand jitter from flickering.
struct DrinkGestureDetector: Equatable {
    /// `gravity.z` above which a sip begins.
    var enterThreshold: Double = 0.40
    /// `gravity.z` below which a sip ends.
    var exitThreshold: Double = 0.30
    /// `gravity.z` range mapped to `drinkFactor` 0...1 while sipping.
    var rampStart: Double = 0.35
    var rampEnd: Double = 0.85
    /// Reject the gesture when the phone is rolled this far sideways.
    var maxSideways: Double = 0.5
    /// Time constant of the low-pass filter in seconds.
    var smoothing: TimeInterval = 0.15

    private(set) var isDrinking = false
    /// Unfiltered factor for the latest sample.
    private(set) var rawFactor: Double = 0
    /// Smoothed factor in 0...1. This is what the animation uses.
    private(set) var drinkFactor: Double = 0

    @discardableResult
    mutating func update(gravity: Gravity, dt: TimeInterval) -> Double {
        let g = gravity.normalized
        let sideways = abs(g.x) > maxSideways

        if sideways {
            isDrinking = false
        } else if !isDrinking, g.z > enterThreshold {
            isDrinking = true
        } else if isDrinking, g.z < exitThreshold {
            isDrinking = false
        }

        rawFactor = isDrinking ? smoothstep(rampStart, rampEnd, g.z) : 0

        guard dt > 0, dt.isFinite else { return drinkFactor }
        let alpha = smoothing > 0 ? 1 - exp(-dt / smoothing) : 1
        drinkFactor += (rawFactor - drinkFactor) * alpha
        if abs(drinkFactor - rawFactor) < 0.0005 { drinkFactor = rawFactor }
        return drinkFactor
    }

    mutating func reset() {
        isDrinking = false
        rawFactor = 0
        drinkFactor = 0
    }
}
