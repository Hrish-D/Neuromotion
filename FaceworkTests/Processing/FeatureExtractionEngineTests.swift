import XCTest
@testable import Facework

@MainActor
final class FeatureExtractionEngineTests: XCTestCase {
    private let engine = FeatureExtractionEngine()
    private let config = TaskConfiguration.default(for: .smileClosed)
    private let passingQC = QCSummary(overallPassed: true, reasons: [],
                                      percentFramesPassing: 1, validForAnalysis: true)

    func testSignalNeverReachesOnsetThreshold() {
        let metrics = derive(left: [0, 0.05, 0.1, 0.1, 0.1, 0.1])
        XCTAssertNil(metrics.onsetTimeLeft)
    }

    func testSignalSustainedForConfiguredDurationHasKnownOnsetPeakAndTimeToPeak() {
        let metrics = derive(left: [0, 0, 1, 1, 1, 1, 1])
        assertOptionalEqual(metrics.onsetTimeLeft, 0.2, accuracy: 0.000_001)
        assertOptionalEqual(metrics.peakAmplitudeLeft, 1, accuracy: 0.000_001)
        assertOptionalEqual(metrics.timeToPeakLeft, 0.4, accuracy: 0.000_001)
    }

    func testSignalBelowThresholdAfterSmoothingHasNoOnset() {
        let metrics = derive(left: [0, 0, 0.5, 0, 0, 0])
        XCTAssertNil(metrics.onsetTimeLeft)
    }

    func testQualifyingFinalSampleWithoutObservedDurationDoesNotEstablishOnset() {
        // Before Prompt 8 this expected 0.4 because the truncated sample range was accepted.
        // Timestamp-aware sustain cannot infer unobserved future qualifying duration.
        let metrics = derive(left: [0, 0, 0, 0, 1])
        XCTAssertNil(metrics.onsetTimeLeft)
    }

    func testKnownHoldStabilityUsesAllSmoothedValuesAtOrAboveHoldThreshold() {
        let metrics = derive(left: [0, 0, 1, 1, 1, 1, 1])
        assertOptionalEqual(metrics.holdStability, 0.221_735_578, accuracy: 0.000_001)
    }

    func testMissingLeftSignalLeavesLeftMetricsNil() {
        let frames = (0..<6).map {
            TestFixtures.frame(index: $0, timestamp: Double($0) * 0.1,
                               task: .smileClosed,
                               raw: ["mouthSmileRight": Double($0) / 5],
                               normalized: ["mouthSmileRight": Double($0) / 5])
        }
        let metrics = engine.deriveMetrics(for: .smileClosed, frames: frames,
                                           config: config, qcSummary: passingQC)
        XCTAssertNil(metrics.peakAmplitudeLeft)
        XCTAssertNotNil(metrics.peakAmplitudeRight)
    }

    func testMissingRightSignalLeavesRightMetricsNil() {
        let metrics = derive(left: [0, 0.2, 0.4, 0.6, 0.8])
        XCTAssertNotNil(metrics.peakAmplitudeLeft)
        XCTAssertNil(metrics.peakAmplitudeRight)
    }

    func testUnilateralTaskStoresSignalInLeftMetricSlots() {
        let values = [0.0, 0.3, 0.6, 0.9, 1.0]
        let frames = values.indices.map {
            TestFixtures.frame(index: $0, timestamp: Double($0) * 0.1,
                               task: .lipPucker, raw: ["mouthPucker": values[$0]],
                               normalized: ["mouthPucker": values[$0]])
        }
        let metrics = engine.deriveMetrics(for: .lipPucker, frames: frames,
                                           config: .default(for: .lipPucker),
                                           qcSummary: passingQC)
        XCTAssertNotNil(metrics.peakAmplitudeLeft)
        XCTAssertNil(metrics.peakAmplitudeRight)
        XCTAssertNil(metrics.symmetry)
    }

    func testBilateralCheekTaskUsesSingleCheekPuffCoefficient() {
        let values = [0.0, 0.4, 0.8, 1.0, 0.9]
        let frames = values.indices.map {
            TestFixtures.frame(index: $0, timestamp: Double($0) * 0.1,
                               task: .cheekPuff, raw: ["cheekPuff": values[$0]],
                               normalized: ["cheekPuff": values[$0]])
        }
        let metrics = engine.deriveMetrics(for: .cheekPuff, frames: frames,
                                           config: .default(for: .cheekPuff),
                                           qcSummary: passingQC)
        assertOptionalEqual(metrics.peakAmplitudeLeft, 0.62, accuracy: 0.000_001)
        XCTAssertNil(metrics.peakAmplitudeRight)
    }

    func testIrregularTimestampsDriveVelocityAndTiming() {
        let times: [TimeInterval] = [0, 0.1, 0.3, 0.6, 1.0]
        let frames = TestFixtures.movementFrames(left: [0, 0, 1, 1, 1],
                                                timestamps: times)
        let metrics = engine.deriveMetrics(for: .smileClosed, frames: frames,
                                           config: config, qcSummary: passingQC)
        assertOptionalEqual(metrics.onsetTimeLeft, 0.3, accuracy: 0.000_001)
        assertOptionalEqual(metrics.timeToPeakLeft, 0.7, accuracy: 0.000_001)
    }

    func testEmptyValidFrameSequenceReturnsEmptyMetrics() {
        let frames = TestFixtures.movementFrames(left: [1, 1], invalidIndices: [0, 1])
        XCTAssertEqual(engine.deriveMetrics(for: .smileClosed, frames: frames,
                                            config: config, qcSummary: passingQC),
                       .empty)
    }

    func testInvalidFramesAreExcludedFromPeakCalculation() {
        let frames = TestFixtures.movementFrames(left: [0, 10, 1, 1, 1],
                                                invalidIndices: [1])
        let metrics = engine.deriveMetrics(for: .smileClosed, frames: frames,
                                           config: config, qcSummary: passingQC)
        XCTAssertLessThanOrEqual(try! XCTUnwrap(metrics.peakAmplitudeLeft), 1)
    }

    private func derive(left: [Double], right: [Double]? = nil) -> DerivedMetrics {
        engine.deriveMetrics(
            for: .smileClosed,
            frames: TestFixtures.movementFrames(left: left, right: right),
            config: config,
            qcSummary: passingQC
        )
    }
}
