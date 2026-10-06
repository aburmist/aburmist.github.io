import XCTest
@testable import CoffeeTasting

final class DescriptorExtractorTests: XCTestCase {
    private let extractor = DescriptorExtractor()

    func testFindsDescriptorsInOrderOfAppearance() {
        let result = extractor.extract(from: "Really bright and juicy, with caramel sweetness and a lingering finish.")
        XCTAssertEqual(result, ["bright", "juicy", "caramel", "sweet", "lingering"])
    }

    func testMatchesSimplePlurals() {
        XCTAssertEqual(extractor.extract(from: "Lots of berries and dates in there"), ["berry", "date"])
        XCTAssertEqual(extractor.extract(from: "Blueberries all day"), ["blueberry"])
    }

    func testPrefersLongerMultiWordTerms() {
        let result = extractor.extract(from: "Dark chocolate and brown sugar, not milk chocolate.")
        XCTAssertEqual(result, ["dark chocolate", "brown sugar", "milk chocolate"])
    }

    func testDoesNotMatchInsideOtherWords() {
        XCTAssertEqual(extractor.extract(from: "Blueberry"), ["blueberry"], "'berry' must not be found inside 'blueberry'")
        XCTAssertFalse(extractor.extract(from: "a brightly lit room").contains("bright"))
    }

    func testIsCaseInsensitiveAndDeduplicates() {
        let result = extractor.extract(from: "CITRUS. Citrus! more citrus, and some Honey.")
        XCTAssertEqual(result, ["citrus", "honey"])
    }

    func testHyphenatedTermsAcceptSpaces() {
        XCTAssertEqual(extractor.extract(from: "very tea like and wine-like"), ["tea-like", "wine-like"])
    }

    func testEmptyInput() {
        XCTAssertEqual(extractor.extract(from: ""), [])
        XCTAssertEqual(extractor.extract(from: "nothing relevant here"), [])
    }
}
