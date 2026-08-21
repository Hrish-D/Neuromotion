import XCTest
@testable import Facework

@MainActor
final class RepetitionAndTaskAnalyzerTests: XCTestCase {
    private let analyzer = RepetitionAnalyzer()
    private let config = TaskConfiguration.default(for: .smileClosed)

    func testValidFramePercentageAboveThresholdPasses() {
        let result = analyze(validCount: 18, total: 20)
        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.qcSummary.percentFramesPassing, 0.9, accuracy: 0.000_001)
    }

    func testValidFramePercentageExactlyAtThresholdPasses() {
        XCTAssertTrue(analyze(validCount: 17, total: 20).valid)
    }

    func testValidFramePercentageBelowThresholdFailsAndCanBePartial() {
        let result = analyze(validCount: 16, total: 20)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.partial)
    }

    func testTrackingLostInvalidatesEvenWithAllFramesMarkedValid() {
        var frames = makeFrames(validCount: 20, total: 20)
        frames[0] = TestFixtures.frame(index: 0, timestamp: 0, task: .smileClosed,
                                       raw: ["mouthSmileLeft": 0.5],
                                       flags: [.trackingLost], valid: true)
        let result = analyzer.analyze(task: .smileClosed, repetitionIndex: 1,
                                      frames: frames, config: config,
                                      peakFrameReference: nil)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.qcSummary.reasons.contains(.trackingLost))
    }

    func testNoFramesProducesNotEnoughFramesFailure() {
        let result = analyzer.analyze(task: .smileClosed, repetitionIndex: 1,
                                      frames: [], config: config,
                                      peakFrameReference: nil)
        XCTAssertFalse(result.valid)
        XCTAssertEqual(result.qcSummary.reasons, [.notEnoughFrames])
    }

    func testTaskAnalyzerOneRepetition() {
        let summary = TaskAnalyzer().summarize(
            task: .smileClosed,
            repetitions: [TestFixtures.repetition(index: 1, amplitudeLeft: 0.7)]
        )
        XCTAssertEqual(summary.validRepetitionCount, 1)
        XCTAssertEqual(summary.averageMetrics.peakAmplitudeLeft, 0.7)
    }

    func testTaskAnalyzerThreeValidRepetitionsCalculatesCVAndFatigueSlope() {
        let repetitions = [
            TestFixtures.repetition(index: 1, amplitudeLeft: 1, amplitudeRight: nil),
            TestFixtures.repetition(index: 2, amplitudeLeft: 2, amplitudeRight: nil),
            TestFixtures.repetition(index: 3, amplitudeLeft: 3, amplitudeRight: nil)
        ]
        let summary = TaskAnalyzer().summarize(task: .smileClosed, repetitions: repetitions)
        XCTAssertEqual(summary.validRepetitionCount, 3)
        assertOptionalEqual(summary.repeatabilityMetrics["amplitudeCV"], 0.5,
                            accuracy: 0.000_001)
        assertOptionalEqual(summary.repeatabilityMetrics["fatigueAmplitudeSlope"], 1,
                            accuracy: 0.000_001)
        assertOptionalEqual(summary.averageMetrics.fatigueSlope, 1, accuracy: 0.000_001)
    }

    func testTaskAnalyzerMixedValidityExcludesInvalidMetrics() {
        let repetitions = [
            TestFixtures.repetition(index: 1, valid: true, amplitudeLeft: 1),
            TestFixtures.repetition(index: 2, valid: false, amplitudeLeft: 100)
        ]
        let summary = TaskAnalyzer().summarize(task: .smileClosed, repetitions: repetitions)
        XCTAssertEqual(summary.validRepetitionCount, 1)
        XCTAssertEqual(summary.invalidRepetitionCount, 1)
        XCTAssertEqual(summary.averageMetrics.peakAmplitudeLeft, 1)
    }

    func testSessionSummaryDoesNotTreatAnyFrameAsSuccessful() throws {
        try skipCaptureSessionViewModelOnSimulator()
        let viewModel = CaptureSessionViewModel(metadata: TestFixtures.metadata())
        viewModel.allFrames = [
            TestFixtures.frame(flags: [.trackingLost], valid: false)
        ]
        let qc = viewModel.buildSessionSummary().overallQC
        XCTAssertFalse(qc.overallPassed)
        XCTAssertFalse(qc.validForAnalysis)
        XCTAssertTrue(qc.reasons.contains(.calibrationUnavailable))
        XCTAssertTrue(qc.reasons.contains(.missingRequiredTask))
        XCTAssertEqual(qc.percentFramesPassing, 0)
    }

    func testEmptySessionSummaryIsNotSuccessful() throws {
        try skipCaptureSessionViewModelOnSimulator()
        let viewModel = CaptureSessionViewModel(metadata: TestFixtures.metadata())
        let qc = viewModel.buildSessionSummary().overallQC
        XCTAssertFalse(qc.overallPassed)
        XCTAssertFalse(qc.validForAnalysis)
    }

    private func analyze(validCount: Int, total: Int) -> RepetitionResult {
        analyzer.analyze(task: .smileClosed, repetitionIndex: 1,
                         frames: makeFrames(validCount: validCount, total: total),
                         config: config, peakFrameReference: nil)
    }

    private func makeFrames(validCount: Int, total: Int) -> [FrameCapture] {
        (0..<total).map { index in
            TestFixtures.frame(index: index, timestamp: Double(index) * 0.1,
                               task: .smileClosed,
                               raw: ["mouthSmileLeft": Double(index) / Double(max(total, 1))],
                               valid: index < validCount)
        }
    }

    private func skipCaptureSessionViewModelOnSimulator() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil,
            "CaptureSessionViewModel eagerly constructs ARSession, which aborts in the simulator."
        )
    }
}
