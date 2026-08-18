import XCTest
@testable import Facework

final class TemporalSampleUtilitiesTests: XCTestCase {
    private let threshold = 0.2
    private let duration = 0.3

    func testQualifyingFinalSampleDoesNotEstablishSustainedOnset() {
        XCTAssertNil(onset(signal: [0, 0, 1], timestamps: [0, 0.1, 0.2]))
    }

    func testQualifyingSequenceShorterThanDurationDoesNotEstablishOnset() {
        XCTAssertNil(onset(signal: [0, 1, 1, 1], timestamps: [0, 1, 1.1, 1.299]))
    }

    func testIrregularQualifyingSequenceReachingDurationEstablishesOriginalCrossing() {
        XCTAssertEqual(onset(signal: [0, 1, 1, 1, 1],
                             timestamps: [0, 1, 1.117, 1.233, 1.3]), 1)
    }

    func testMoreSamplesWithoutEnoughElapsedTimeDoNotEstablishOnset() {
        XCTAssertNil(onset(signal: [0, 1, 1, 1, 1, 1],
                           timestamps: [0, 1, 1.05, 1.1, 1.15, 1.299]))
    }

    func testFewerSamplesWithEnoughElapsedTimeEstablishOnset() {
        XCTAssertEqual(onset(signal: [0, 1, 1], timestamps: [0, 1, 1.3]), 1)
    }

    func testPhysicalCadenceUsesObservedTimestamps() {
        XCTAssertEqual(onset(signal: [0, 1, 1, 1, 1],
                             timestamps: [0, 1, 1.11665, 1.23330, 1.34995]), 1)
    }

    func testMixedCadenceUsesObservedTimestamps() {
        XCTAssertEqual(onset(signal: [0, 1, 1, 1, 1],
                             timestamps: [0, 1, 1.1, 1.217, 1.367]), 1)
    }

    func testDurationBoundaryUsesDeterministicFloatingPointTolerance() {
        XCTAssertEqual(onset(signal: [0, 1, 1],
                             timestamps: [0, 1, 1.3 - 5e-10]), 1)
        XCTAssertNil(onset(signal: [0, 1, 1],
                           timestamps: [0, 1, 1.3 - 2e-9]))
    }

    func testInvalidIntervalsAreNeverReplacedWithNominalCadence() {
        XCTAssertNil(TemporalSampleUtilities.positiveInterval(from: 1, to: 1))
        XCTAssertNil(TemporalSampleUtilities.positiveInterval(from: 1, to: 0.9))
    }

    private func onset(signal: [Double], timestamps: [TimeInterval]) -> Int? {
        TemporalSampleUtilities.sustainedOnsetIndex(
            signal: signal,
            timestamps: timestamps,
            threshold: threshold,
            requiredDuration: duration
        )
    }
}
