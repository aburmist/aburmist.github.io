import Foundation

/// Gravity vector in the device's coordinate frame (same convention as CoreMotion):
/// +x points to the right edge of the phone, +y to the top edge, +z out of the screen
/// toward the user. Upright portrait is `(0, -1, 0)`; lying screen-up on a table is `(0, 0, -1)`.
struct Gravity: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    static let upright = Gravity(x: 0, y: -1, z: 0)

    /// Returns a unit-length copy, or `upright` when the vector is degenerate.
    var normalized: Gravity {
        let length = (x * x + y * y + z * z).squareRoot()
        guard length > 1e-6 else { return .upright }
        return Gravity(x: x / length, y: y / length, z: z / length)
    }
}

@inline(__always)
func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

/// Hermite smoothstep: 0 below `edge0`, 1 above `edge1`, smooth in between.
func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x >= edge1 ? 1 : 0 }
    let t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
}
