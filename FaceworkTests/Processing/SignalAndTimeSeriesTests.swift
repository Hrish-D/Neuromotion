import XCTest
@testable import Facework

final class SignalAndTimeSeriesTests: XCTestCase {
    func testMovingAverageKnownSequence() {
        XCTAssertEqual(TimeSeriesUtils.movingAverage(values: [1, 2, 3, 4, 5], window: 3),
                       [1, 1.5, 2, 3, 4])
    }

    func testMovingAverageShorterThanWindowIsUnchanged() {
        XCTAssertEqual(TimeSeriesUtils.movingAverage(values: [1, 2], window: 5), [1, 2])
    }

    func testMovingAverageOneValueAndEmptySequence() {
        XCTAssertEqual(TimeSeriesUtils.movingAverage(values: [7], window: 5), [7])
        XCTAssertEqual(TimeSeriesUtils.movingAverage(values: [], window: 5), [])
    }

    func testDuplicatedMovingAverageWrappersMatch() {
        XCTAssertEqual(TimeSeriesUtils.movingAverage([1, 2, 3], window: 2),
                       TimeSeriesUtils.movingAverage(values: [1, 2, 3], window: 2))
    }

    func testLinearSlopeIncreasingDecreasingAndConstant() {
        XCTAssertEqual(TimeSeriesUtils.linearSlope([1, 2, 3]), 1, accuracy: 0.000_001)
        XCTAssertEqual(TimeSeriesUtils.linearSlope([3, 2, 1]), -1, accuracy: 0.000_001)
        XCTAssertEqual(TimeSeriesUtils.linearSlope([2, 2, 2]), 0, accuracy: 0.000_001)
    }

    func testSlopeWrapperUsesSampleOrderRatherThanTimestamps() {
        XCTAssertEqual(TimeSeriesUtils.slope([0, 2, 4]), 2, accuracy: 0.000_001)
        XCTAssertEqual(TimeSeriesUtils.linearSlope(x: [10, 20, 30], y: [0, 2, 4]),
                       0.2, accuracy: 0.000_001)
    }

    func testSignalPreprocessorUsesNormalizedValuesAndConfiguredWindow() {
        let frames = (0..<5).map {
            TestFixtures.frame(index: $0, normalized: ["a": Double($0 + 1)])
        }
        XCTAssertEqual(SignalPreprocessor().preprocess(frames: frames, key: "a"),
                       [1, 1.5, 2, 2.5, 3])
    }

    func testSignalPreprocessorExcludesInvalidFramesAndDefaultsMissingToZero() {
        let frames = [
            TestFixtures.frame(index: 0, normalized: ["a": 1]),
            TestFixtures.frame(index: 1, normalized: ["a": 9], valid: false),
            TestFixtures.frame(index: 2, normalized: [:])
        ]
        XCTAssertEqual(SignalPreprocessor().preprocess(frames: frames, key: "a"), [1, 0])
    }
}
