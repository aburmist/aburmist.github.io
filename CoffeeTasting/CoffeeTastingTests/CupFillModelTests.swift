import XCTest
@testable import CoffeeTasting

final class CupFillModelTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60.0

    /// Runs the model and returns every non-`.none` event in order.
    private func run(_ model: inout CupFillModel, drinkFactor: Double, seconds: Double) -> [CupFillModel.Event] {
        var events: [CupFillModel.Event] = []
        for _ in 0..<Int(seconds / dt) {
            let event = model.update(drinkFactor: drinkFactor, dt: dt)
            if event != .none { events.append(event) }
        }
        return events
    }

    func testFreshCupIsFullAndSteaming() {
        let model = CupFillModel()
        XCTAssertEqual(model.fillLevel, 1)
        XCTAssertFalse(model.isEmpty)
        XCTAssertEqual(model.steamIntensity, 1, accuracy: 1e-9)
    }

    func testSipLowersTheLevelAndAnnouncesItself() {
        var model = CupFillModel()
        let events = run(&model, drinkFactor: 1, seconds: 2)
        XCTAssertEqual(events.first, .sipStarted)
        XCTAssertEqual(events.filter { $0 == .sipStarted }.count, 1, "one continuous sip announces once")
        XCTAssertEqual(model.fillLevel, 1 - 0.06 * 2, accuracy: 0.01)
        XCTAssertTrue(model.isSipping)
    }

    func testBelowThresholdDoesNotSip() {
        var model = CupFillModel()
        let events = run(&model, drinkFactor: 0.5, seconds: 2)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(model.fillLevel, 1)
    }

    func testDrinkingLongEnoughEmptiesTheCup() {
        var model = CupFillModel()
        let events = run(&model, drinkFactor: 1, seconds: 20)
        XCTAssertTrue(model.isEmpty)
        XCTAssertTrue(events.contains(.becameEmpty))
        XCTAssertEqual(model.steamIntensity, 0)
    }

    func testEmptyCupRefillsAfterIdleDelay() {
        var model = CupFillModel()
        _ = run(&model, drinkFactor: 1, seconds: 20)
        XCTAssertTrue(model.isEmpty)

        var events = run(&model, drinkFactor: 0, seconds: 5)
        XCTAssertTrue(events.isEmpty, "no refill before the idle delay")

        events = run(&model, drinkFactor: 0, seconds: 1.5)
        XCTAssertTrue(events.contains(.refillStarted))
        XCTAssertTrue(model.isRefilling)

        events = run(&model, drinkFactor: 0, seconds: 2.5)
        XCTAssertTrue(events.contains(.refillFinished))
        XCTAssertEqual(model.fillLevel, 1)
        XCTAssertFalse(model.isRefilling)
        XCTAssertEqual(model.heat, 1, accuracy: 0.01)
    }

    func testPartialCupWaitsLongerBeforeRefilling() {
        var model = CupFillModel()
        _ = run(&model, drinkFactor: 1, seconds: 3)
        let events = run(&model, drinkFactor: 0, seconds: 20)
        XCTAssertTrue(events.isEmpty)
        XCTAssertLessThan(model.fillLevel, 1)
    }

    func testManualRefillPoursImmediately() {
        var model = CupFillModel()
        _ = run(&model, drinkFactor: 1, seconds: 5)
        XCTAssertEqual(model.refill(), .refillStarted)
        let events = run(&model, drinkFactor: 0, seconds: 2.5)
        XCTAssertTrue(events.contains(.refillFinished))
        XCTAssertEqual(model.fillLevel, 1)
    }

    func testManualRefillOnFullCupOnlyReheats() {
        var model = CupFillModel()
        _ = run(&model, drinkFactor: 0, seconds: 120)
        XCTAssertLessThan(model.heat, 1)
        XCTAssertEqual(model.refill(), .none)
        XCTAssertEqual(model.heat, 1)
    }

    func testCoffeeCoolsOverTime() {
        var model = CupFillModel()
        _ = run(&model, drinkFactor: 0, seconds: 300)
        XCTAssertEqual(model.heat, 0.5, accuracy: 0.02)
        XCTAssertEqual(model.steamIntensity, 0.5, accuracy: 0.02)
    }
}
