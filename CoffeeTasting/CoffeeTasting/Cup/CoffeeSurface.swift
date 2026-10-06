import SceneKit
import UIKit

/// Geometry, textures and the vertex shader for the liquid surface.
///
/// The surface is a flat, finely tessellated disk. All tilting and rippling happens in the
/// shader by displacing vertex heights, which keeps the liquid's outline pressed against the
/// cup wall no matter how far it tilts (a rotated disk would leave crescent-shaped gaps).
enum CoffeeSurface {
    /// SceneKit geometry shader modifier (Metal Shading Language).
    ///
    /// Uniforms, set via KVC on the material:
    /// - `slopeX`, `slopeZ`: rise per unit distance toward +x / +z (tan of the tilt angles)
    /// - `rippleAmp`: ripple amplitude in scene units (0 = glassy)
    /// - `time`: seconds, drives the ripple phase
    /// - `radius`: disk radius, used to normalise ring waves
    static let geometryShader = """
    #pragma arguments
    float slopeX;
    float slopeZ;
    float rippleAmp;
    float time;
    float radius;
    #pragma body
    float3 p = _geometry.position.xyz;
    float safeRadius = max(radius, 0.001);
    float r = length(p.xz);
    float rn = r / safeRadius;
    float k1 = 26.0;
    float w1 = 9.0;
    float phase1 = rn * k1 - time * w1;
    float kx = 17.0;
    float kz = 11.0;
    float w2 = 7.0;
    float phase2 = p.x * kx + p.z * kz + time * w2;
    float envelope = 0.35 + 0.65 * rn;
    float ripple = 0.6 * sin(phase1) * envelope + 0.4 * sin(phase2);
    float h = slopeX * p.x + slopeZ * p.z + rippleAmp * ripple;
    _geometry.position.y += h;
    float safeR = max(r, 0.0005);
    float drdx = p.x / safeR;
    float drdz = p.z / safeR;
    float d1 = 0.6 * cos(phase1) * (k1 / safeRadius) * envelope;
    float d2 = 0.4 * cos(phase2);
    float dhdx = slopeX + rippleAmp * (d1 * drdx + d2 * kx);
    float dhdz = slopeZ + rippleAmp * (d1 * drdz + d2 * kz);
    _geometry.normal = normalize(float3(-dhdx, 1.0, -dhdz));
    """

    /// Builds a disk tessellated as concentric rings so the rim is a clean circle.
    static func makeGeometry(radius: Float, rings: Int = 28, segments: Int = 72) -> SCNGeometry {
        var vertices: [SCNVector3] = [SCNVector3(0, 0, 0)]
        var normals: [SCNVector3] = [SCNVector3(0, 1, 0)]
        var uvs: [CGPoint] = [CGPoint(x: 0.5, y: 0.5)]

        for ring in 1...rings {
            let r = radius * Float(ring) / Float(rings)
            for segment in 0..<segments {
                let angle = Float(segment) / Float(segments) * 2 * Float.pi
                let x = r * cos(angle)
                let z = r * sin(angle)
                vertices.append(SCNVector3(x, 0, z))
                normals.append(SCNVector3(0, 1, 0))
                uvs.append(CGPoint(x: CGFloat(0.5 + x / (2 * radius)), y: CGFloat(0.5 + z / (2 * radius))))
            }
        }

        func index(ring: Int, segment: Int) -> Int32 {
            ring == 0 ? 0 : Int32(1 + (ring - 1) * segments + (segment % segments))
        }

        var indices: [Int32] = []
        indices.reserveCapacity(segments * 3 + (rings - 1) * segments * 6)
        // Centre fan (counter-clockwise when seen from above, i.e. facing +y).
        for s in 0..<segments {
            indices += [0, index(ring: 1, segment: s + 1), index(ring: 1, segment: s)]
        }
        // Quads between consecutive rings.
        for ring in 1..<rings {
            for s in 0..<segments {
                let a = index(ring: ring, segment: s)
                let b = index(ring: ring, segment: s + 1)
                let c = index(ring: ring + 1, segment: s)
                let d = index(ring: ring + 1, segment: s + 1)
                indices += [a, d, c, a, b, d]
            }
        }

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [element]
        )
        return geometry
    }

    /// Dark coffee with a lighter crema ring and a few specks near the rim.
    static func makeCremaTexture(size: Int = 512) -> UIImage {
        let side = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: side / 2, y: side / 2)
            let colors = [
                UIColor(red: 0.15, green: 0.085, blue: 0.04, alpha: 1).cgColor,
                UIColor(red: 0.19, green: 0.105, blue: 0.05, alpha: 1).cgColor,
                UIColor(red: 0.30, green: 0.18, blue: 0.09, alpha: 1).cgColor,
                UIColor(red: 0.47, green: 0.31, blue: 0.17, alpha: 1).cgColor,
            ]
            let locations: [CGFloat] = [0, 0.70, 0.92, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) {
                cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: side / 2, options: [.drawsAfterEndLocation])
            }

            // Crema specks concentrated near the wall. Deterministic so every launch looks the same.
            var rng = SeededGenerator(seed: 0xC0FFEE)
            for _ in 0..<1600 {
                let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                let radius = Double.random(in: 0.74...1.0, using: &rng) * Double(side / 2)
                let x = Double(center.x) + cos(angle) * radius
                let y = Double(center.y) + sin(angle) * radius
                let diameter = Double.random(in: 1.5...5, using: &rng)
                let alpha = Double.random(in: 0.05...0.22, using: &rng)
                cg.setFillColor(UIColor(red: 0.72, green: 0.55, blue: 0.33, alpha: alpha).cgColor)
                cg.fillEllipse(in: CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter))
            }

            // A soft, slightly lighter swirl in the middle so the centre is not a flat void.
            let swirl = [
                UIColor(red: 0.26, green: 0.16, blue: 0.08, alpha: 0.35).cgColor,
                UIColor(red: 0.26, green: 0.16, blue: 0.08, alpha: 0).cgColor,
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: swirl as CFArray, locations: [0, 1]) {
                let c = CGPoint(x: side * 0.42, y: side * 0.40)
                cg.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: side * 0.28, options: [])
            }
        }
    }

    /// A tiny lat-long environment: bright sky, warm horizon band, dark floor, one "window".
    /// Reflected by the glossy liquid so it reads as a real surface.
    static func makeEnvironmentImage() -> UIImage {
        let size = CGSize(width: 256, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.78, green: 0.84, blue: 0.92, alpha: 1).cgColor,
                UIColor(red: 0.92, green: 0.90, blue: 0.86, alpha: 1).cgColor,
                UIColor(red: 0.35, green: 0.30, blue: 0.26, alpha: 1).cgColor,
                UIColor(red: 0.12, green: 0.10, blue: 0.09, alpha: 1).cgColor,
            ]
            let locations: [CGFloat] = [0, 0.45, 0.55, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            // A bright window-like patch gives the surface a crisp highlight.
            cg.setFillColor(UIColor(white: 1, alpha: 0.9).cgColor)
            cg.fill(CGRect(x: 40, y: 18, width: 46, height: 30))
            cg.setFillColor(UIColor(white: 1, alpha: 0.5).cgColor)
            cg.fill(CGRect(x: 170, y: 22, width: 30, height: 20))
        }
    }

    /// Soft radial shadow used under the cup.
    static func makeShadowTexture(size: Int = 256) -> UIImage {
        let side = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let center = CGPoint(x: side / 2, y: side / 2)
            let colors = [
                UIColor(white: 0, alpha: 0.55).cgColor,
                UIColor(white: 0, alpha: 0.25).cgColor,
                UIColor(white: 0, alpha: 0).cgColor,
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.45, 1]) {
                ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: side / 2, options: [])
            }
        }
    }

    /// Soft white blob used as the steam particle sprite.
    static func makeSteamSprite(size: Int = 128) -> UIImage {
        let side = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let center = CGPoint(x: side / 2, y: side / 2)
            let colors = [
                UIColor(white: 1, alpha: 1).cgColor,
                UIColor(white: 1, alpha: 0.35).cgColor,
                UIColor(white: 1, alpha: 0).cgColor,
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.4, 1]) {
                ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: side / 2, options: [])
            }
        }
    }
}

/// Small deterministic generator so procedural textures are identical on every launch.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
