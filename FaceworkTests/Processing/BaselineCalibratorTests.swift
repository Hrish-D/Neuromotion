import XCTest
@testable import Facework

final class BaselineCalibratorTests: XCTestCase {
    private let calibrator = BaselineCalibrator()

    func testArithmeticMeanUsesValidNeutralFrames() {
        let result = calibrator.computeBaseline(from: TestFixtures.neutralFrames(values: [0.1, 0.2, 0.3]))
        assertOptionalEqual(result?["mouthSmileLeft"], 0.2, accuracy: 0.000_001)
    }

    func testInvalidFramesAreExcludedWhenAValidFrameExists() {
        let frames = [
            TestFixtures.frame(index: 0, raw: ["a": 1], valid: false),
            TestFixtures.frame(index: 1, raw: ["a": 3], valid: true)
        ]
        XCTAssertEqual(calibrator.computeBaseline(from: frames)?["a"], 3)
    }

    func testInvalidFramesDoNotProduceFallbackBaseline() {
        let frames = [
            TestFixtures.frame(index: 0, raw: ["a": 1], valid: false),
            TestFixtures.frame(index: 1, raw: ["a": 3], valid: false)
        ]
        XCTAssertNil(calibrator.computeBaseline(from: frames))
    }

    func testMissingBlendshapeKeyUsesOnlyPresentValues() {
        let frames = [
            TestFixtures.frame(index: 0, raw: ["a": 2]),
            TestFixtures.frame(index: 1, raw: [:])
        ]
        XCTAssertEqual(calibrator.computeBaseline(from: frames)?["a"], 2)
    }

    func testUnequalKeySetsAreAveragedIndependently() {
        let frames = [
            TestFixtures.frame(index: 0, raw: ["a": 1]),
            TestFixtures.frame(index: 1, raw: ["b": 4])
        ]
        XCTAssertEqual(calibrator.computeBaseline(from: frames), ["a": 1, "b": 4])
    }

    func testEmptyInputProducesNoBaseline() {
        XCTAssertNil(calibrator.computeBaseline(from: []))
    }

    func testNormalizationSubtractsBaselineAndUnionsKeys() {
        let result = calibrator.normalize(raw: ["a": 0.8, "rawOnly": 0.4],
                                          baseline: ["a": 0.3, "baseOnly": 0.2])
        assertOptionalEqual(result["a"], 0.5, accuracy: 0.000_001)
        XCTAssertEqual(result["rawOnly"], 0.4)
        XCTAssertEqual(result["baseOnly"], -0.2)
        XCTAssertEqual(result.keys.sorted(), ["a", "baseOnly", "rawOnly"])
    }
}
