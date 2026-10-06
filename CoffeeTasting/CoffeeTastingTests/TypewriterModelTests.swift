import XCTest
@testable import CoffeeTasting

final class TypewriterModelTests: XCTestCase {
    func testRevealsOneCharacterPerTick() {
        let model = TypewriterModel()
        model.setTarget("hello")
        XCTAssertEqual(model.displayed, "")
        XCTAssertTrue(model.tick())
        XCTAssertEqual(model.displayed, "h")
        model.tick(); model.tick()
        XCTAssertEqual(model.displayed, "hel")
        XCTAssertFalse(model.isCaughtUp)
    }

    func testTickReturnsFalseWhenCaughtUp() {
        let model = TypewriterModel()
        model.setTarget("ab")
        model.tick(); model.tick()
        XCTAssertTrue(model.isCaughtUp)
        XCTAssertFalse(model.tick())
        XCTAssertEqual(model.displayed, "ab")
    }

    func testAppendedTargetContinuesTyping() {
        let model = TypewriterModel()
        model.setTarget("bright")
        for _ in 0..<6 { model.tick() }
        model.setTarget("bright citrus")
        model.tick()
        XCTAssertEqual(model.displayed, "bright ")
        model.tick()
        XCTAssertEqual(model.displayed, "bright c")
    }

    func testCorrectionBacksUpToCommonPrefixThenRetypes() {
        let model = TypewriterModel()
        model.setTarget("hello world")
        for _ in 0..<7 { model.tick() }
        XCTAssertEqual(model.displayed, "hello w")

        model.setTarget("help me")
        XCTAssertTrue(model.tick())
        XCTAssertEqual(model.displayed, "hel", "backs up to the shared prefix")
        model.tick()
        XCTAssertEqual(model.displayed, "help")
        for _ in 0..<10 { model.tick() }
        XCTAssertEqual(model.displayed, "help me")
    }

    func testFlushShowsEverything() {
        let model = TypewriterModel()
        model.setTarget("smooth finish")
        model.flush()
        XCTAssertEqual(model.displayed, "smooth finish")
        XCTAssertTrue(model.isCaughtUp)
    }

    func testResetClearsBoth() {
        let model = TypewriterModel()
        model.setTarget("abc")
        model.tick()
        model.reset()
        XCTAssertEqual(model.displayed, "")
        XCTAssertEqual(model.target, "")
    }

    func testCharactersPerTickCanBeRaised() {
        let model = TypewriterModel()
        model.charactersPerTick = 3
        model.setTarget("abcdefg")
        model.tick()
        XCTAssertEqual(model.displayed, "abc")
        model.tick(); model.tick()
        XCTAssertEqual(model.displayed, "abcdefg")
    }
}
