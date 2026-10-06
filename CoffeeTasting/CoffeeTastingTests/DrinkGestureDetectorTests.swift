import XCTest
@testable import CoffeeTasting

final class DrinkGestureDetectorTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60.0

    private func hold(_ detector: inout DrinkGestureDetector, gravity: Gravity, seconds: Double) -> Double {
        var value = 0.0
        for _ in 0..<Int(seconds / dt) {
            value = detector.update(gravity: gravity, dt: dt)
        }
        return value
    }

    func testUprightIsNotDrinking() {
        var detector = DrinkGestureDetector()
        let value = hold(&detector, gravity: .upright, seconds: 1)
        XCTAssertEqual(value, 0)
        XCTAssertFalse(detector.isDrinking)
    }

    func testTippingTopTowardFaceRampsToFull() {
        var detector = DrinkGestureDetector()
        // Screen facing mostly downward toward the chest: gravity.z strongly positive.
        let value = hold(&detector, gravity: Gravity(x: 0, y: -0.4, z: 0.92), seconds: 2)
        XCTAssertTrue(detector.isDrinking)
        XCTAssertEqual(value, 1, accuracy: 0.01)
    }

    func testSmoothingMakesTheFactorContinuous() {
        var detector = DrinkGestureDetector()
        let first = detector.update(gravity: Gravity(x: 0, y: -0.4, z: 0.92), dt: dt)
        XCTAssertGreaterThan(first, 0)
        XCTAssertLessThan(first, 0.3, "one frame should not jump straight to a full sip")
    }

    func testHysteresisKeepsASipAliveThroughSmallDips() {
        var detector = DrinkGestureDetector()
        _ = hold(&detector, gravity: Gravity(x: 0, y: -0.85, z: 0.36), seconds: 0.5)
        XCTAssertFalse(detector.isDrinking, "0.36 is below the enter threshold")

        _ = hold(&detector, gravity: Gravity(x: 0, y: -0.85, z: 0.5), seconds: 0.5)
        XCTAssertTrue(detector.isDrinking)

        _ = hold(&detector, gravity: Gravity(x: 0, y: -0.93, z: 0.35), seconds: 0.5)
        XCTAssertTrue(detector.isDrinking, "0.35 is above the exit threshold, so the sip continues")

        let value = hold(&detector, gravity: Gravity(x: 0, y: -0.96, z: 0.25), seconds: 2)
        XCTAssertFalse(detector.isDrinking)
        XCTAssertEqual(value, 0, accuracy: 0.01)
    }

    func testSidewaysRollIsRejected() {
        var detector = DrinkGestureDetector()
        let value = hold(&detector, gravity: Gravity(x: 0.8, y: -0.3, z: 0.52), seconds: 2)
        XCTAssertFalse(detector.isDrinking)
        XCTAssertEqual(value, 0, accuracy: 0.01)
    }

    func testResetClearsState() {
        var detector = DrinkGestureDetector()
        _ = hold(&detector, gravity: Gravity(x: 0, y: -0.4, z: 0.92), seconds: 1)
        detector.reset()
        XCTAssertEqual(detector.drinkFactor, 0)
        XCTAssertFalse(detector.isDrinking)
    }
}
