import XCTest
@testable import CoffeeTasting

final class CoffeeSloshSimulatorTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60.0

    private func run(_ sim: inout CoffeeSloshSimulator, gravity: Gravity, seconds: Double, extraTiltZ: Double = 0) {
        let steps = Int(seconds / dt)
        for _ in 0..<steps {
            sim.step(gravity: gravity, extraTiltZ: extraTiltZ, dt: dt)
        }
    }

    func testUprightPhoneKeepsSurfaceLevel() {
        var sim = CoffeeSloshSimulator()
        run(&sim, gravity: .upright, seconds: 3)
        XCTAssertEqual(sim.tiltX, 0, accuracy: 1e-6)
        XCTAssertEqual(sim.tiltZ, 0, accuracy: 1e-6)
        XCTAssertEqual(sim.energy, 0, accuracy: 1e-6)
    }

    func testTargetTiltFollowsGravity() {
        let right = CoffeeSloshSimulator.targetTilt(for: Gravity(x: 0.5, y: -0.866, z: 0))
        XCTAssertEqual(right.tiltX, 30 * .pi / 180, accuracy: 0.01)
        XCTAssertEqual(right.tiltZ, 0, accuracy: 1e-6)

        let towardViewer = CoffeeSloshSimulator.targetTilt(for: Gravity(x: 0, y: -0.7, z: 0.7))
        XCTAssertEqual(towardViewer.tiltX, 0, accuracy: 1e-6)
        XCTAssertEqual(towardViewer.tiltZ, 45 * .pi / 180, accuracy: 0.01)
    }

    func testLiquidRisesOnTheLowSideAndIsClamped() {
        var sim = CoffeeSloshSimulator()
        run(&sim, gravity: Gravity(x: 0.5, y: -0.866, z: 0), seconds: 4)
        XCTAssertGreaterThan(sim.tiltX, 0)
        XCTAssertEqual(sim.tiltX, sim.maxTilt, accuracy: 0.02, "30° of roll should settle at the clamp")
        XCTAssertEqual(sim.tiltZ, 0, accuracy: 0.02)
    }

    func testSurfaceOvershootsBeforeSettling() {
        var sim = CoffeeSloshSimulator()
        let gravity = Gravity(x: 0.2, y: -0.98, z: 0)
        var peak = 0.0
        for _ in 0..<(60 * 4) {
            sim.step(gravity: gravity, dt: dt)
            peak = max(peak, sim.tiltX)
        }
        XCTAssertGreaterThan(peak, sim.tiltX + 0.01, "an underdamped spring should wobble past its target")
    }

    func testExtraTiltZAddsDrinkingLean() {
        var sim = CoffeeSloshSimulator()
        run(&sim, gravity: .upright, seconds: 3, extraTiltZ: 0.3)
        XCTAssertEqual(sim.tiltZ, 0.3, accuracy: 0.02)
    }

    func testDegenerateInputsNeverProduceNaN() {
        var sim = CoffeeSloshSimulator()
        sim.step(gravity: Gravity(x: 0, y: 0, z: 0), dt: dt)
        sim.step(gravity: .upright, dt: 0)
        sim.step(gravity: .upright, dt: .infinity)
        sim.step(gravity: .upright, dt: .nan)
        run(&sim, gravity: Gravity(x: 1, y: 0, z: 0), seconds: 2)
        XCTAssertFalse(sim.tiltX.isNaN)
        XCTAssertFalse(sim.tiltZ.isNaN)
        XCTAssertFalse(sim.energy.isNaN)
        XCTAssertLessThanOrEqual(abs(sim.tiltX), sim.maxTilt * 1.2 + 1e-9)
    }
}
