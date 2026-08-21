import XCTest
@testable import Facework

@MainActor
final class NeutralCalibrationEvaluatorTests: XCTestCase {
    private let evaluator = NeutralCalibrationEvaluator()

    func testFullTrustworthyIrregularAttemptProducesArithmeticMeanBaseline() {
        let timestamps = physicalTimestamps(through: 2.45)
        let frames = timestamps.enumerated().map { frame(index: $0, timestamp: $1, value: 0.4) }
        let result = evaluate(frames: frames, events: trackingEvents(timestamps))

        guard case .success(let baseline, let eligible, let diagnostics) = result else {
            return XCTFail("Expected calibration success")
        }
        XCTAssertEqual(baseline["a"] ?? .nan, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(eligible.count, frames.count)
        XCTAssertGreaterThanOrEqual(diagnostics.continuousTrackedDurationSeconds, 2.35)
        XCTAssertEqual(diagnostics.requiredTrackedDurationSeconds, 2.35, accuracy: 0.000_001)
    }

    func testActivationWarningThroughoutDoesNotBlockTrustworthyAttempt() {
        let timestamps = physicalTimestamps(through: 2.45)
        var frames: [FrameCapture] = []
        for (index, timestamp) in timestamps.enumerated() {
            let raw = rawFrame(index: index, timestamp: timestamp, value: 0.151)
            frames.append(FrameProcessor().process(raw: raw, baseline: [:], previous: frames.last))
        }
        let result = evaluate(frames: frames, events: trackingEvents(timestamps))

        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(frames.allSatisfy { $0.qcFlags.contains(.facialActivationTooHighAtNeutral) })
        XCTAssertTrue(frames.allSatisfy(\.isValidFrame))
        XCTAssertEqual(result.diagnostics.warningCount, frames.count)
    }

    func testPhysicalFailureFaceBrieflyThenAbsentForRemainderFails() {
        let trackedTimes = [0.000, 0.117, 0.233]
        let frames = trackedTimes.enumerated().map { frame(index: $0, timestamp: $1, value: 0.2) }
        let noFaceTimes = stride(from: 0.250, through: 2.450, by: 0.117).map { $0 }
        let events = trackingEvents(trackedTimes) + noFaceTimes.map { event(timestamp: $0, state: .noFace) }

        let result = evaluate(frames: frames, events: events)

        XCTAssertFalse(result.isSuccessful)
        XCTAssertNil(result.baseline)
        XCTAssertFalse(result.allowsTaskNavigation)
        XCTAssertTrue(result.diagnostics.rejectionReasons.contains(.noFace))
    }

    func testNoFaceForEntireAttemptFails() {
        let events = physicalTimestamps(through: 2.45).map { event(timestamp: $0, state: .noFace) }
        let result = evaluate(frames: [], events: events)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertNil(result.baseline)
    }

    func testMultipleFacesAndLimitedTrackingAreHardAttemptFailures() {
        let timestamps = physicalTimestamps(through: 2.45)
        let frames = timestamps.enumerated().map { frame(index: $0, timestamp: $1, value: 0.2) }

        var multipleEvents = trackingEvents(timestamps)
        multipleEvents[5] = event(timestamp: timestamps[5], state: .multipleFaces, faceCount: 2)
        XCTAssertFalse(evaluate(frames: frames, events: multipleEvents).isSuccessful)

        var limitedEvents = trackingEvents(timestamps)
        limitedEvents[5] = event(timestamp: timestamps[5], cameraState: "limited(excessiveMotion)")
        XCTAssertFalse(evaluate(frames: frames, events: limitedEvents).isSuccessful)
    }

    func testShortTrackedCoverageFailsWithoutFixedFrameCountAssumption() {
        let timestamps = [0.000, 0.117, 0.233, 0.350]
        let frames = timestamps.enumerated().map { frame(index: $0, timestamp: $1, value: 0.2) }
        let result = evaluate(frames: frames, events: trackingEvents(timestamps))

        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.diagnostics.continuousTrackedDurationSeconds, 0.350, accuracy: 0.000_001)
        XCTAssertEqual(result.diagnostics.requiredTrackedDurationSeconds, 2.35, accuracy: 0.000_001)
    }

    func testFailedAttemptFollowedByCleanRetryUsesOnlyFreshFrames() {
        let failedFrames = [frame(index: 0, timestamp: 0, value: 99)]
        let failed = evaluate(
            frames: failedFrames,
            events: [event(timestamp: 0), event(timestamp: 0.01, state: .noFace)]
        )
        XCTAssertFalse(failed.isSuccessful)

        let retryTimes = physicalTimestamps(startingAt: 10, through: 12.45)
        let retryFrames = retryTimes.enumerated().map { frame(index: $0, timestamp: $1, value: 0.25) }
        let retry = evaluate(frames: retryFrames, events: trackingEvents(retryTimes))

        guard case .success(let baseline, let eligible, _) = retry else {
            return XCTFail("Expected retry success")
        }
        XCTAssertEqual(baseline["a"] ?? .nan, 0.25, accuracy: 0.000_001)
        XCTAssertFalse(eligible.contains { $0.rawBlendshapes["a"] == 99 })
        XCTAssertTrue(retry.allowsTaskNavigation)
    }

    func testHardRejectedFramesAreExcludedWithoutFallback() {
        let timestamps = physicalTimestamps(through: 2.45)
        var frames = timestamps.enumerated().map { frame(index: $0, timestamp: $1, value: 0.2) }
        frames[5] = frame(index: 5, timestamp: timestamps[5], value: 99,
                          flags: [.signalSpike], valid: false)

        guard case .success(let baseline, let eligible, _) = evaluate(
            frames: frames, events: trackingEvents(timestamps)
        ) else {
            return XCTFail("Expected trustworthy attempt with one excluded signal frame")
        }
        XCTAssertEqual(eligible.count, frames.count - 1)
        XCTAssertEqual(baseline["a"] ?? .nan, 0.2, accuracy: 0.000_001)

        let allRejected = frames.map {
            frame(index: $0.frameIndex, timestamp: $0.timestamp, value: 99,
                  flags: [.trackingLost], valid: false)
        }
        XCTAssertFalse(evaluate(frames: allRejected, events: trackingEvents(timestamps)).isSuccessful)
    }

    func testInvalidEventTimestampFailsDeterministically() {
        let frames = [frame(index: 0, timestamp: 0, value: 0.2)]
        XCTAssertFalse(evaluate(frames: frames, events: [event(timestamp: .nan)]).isSuccessful)
        XCTAssertFalse(evaluate(
            frames: frames,
            events: [event(timestamp: 1), event(timestamp: 0.9)]
        ).isSuccessful)
    }

    func testCalibrationEvaluationDoesNotMutateRawCapture() {
        let timestamps = physicalTimestamps(through: 2.45)
        let captured = timestamps.enumerated().map { frame(index: $0, timestamp: $1, value: 0.25) }
        let rawBefore = captured.map(\.raw)
        _ = evaluate(frames: captured, events: trackingEvents(timestamps))
        XCTAssertEqual(captured.map(\.raw), rawBefore)
    }

    func testLiveStatusNoFaceOverridesStalePassingFrameAndRetryIsFailureOnly() {
        XCTAssertEqual(
            NeutralCalibrationLiveStatus.resolve(
                phase: .capturing,
                latestEvent: event(timestamp: 1, state: .noFace),
                latestFrameIsValid: true
            ),
            .noFace
        )
        XCTAssertFalse(NeutralCalibrationPhase.ready.showsRetryControl)
        XCTAssertFalse(NeutralCalibrationPhase.capturing.showsRetryControl)
        XCTAssertFalse(NeutralCalibrationPhase.checking.showsRetryControl)
        XCTAssertTrue(NeutralCalibrationPhase.failed.showsRetryControl)
    }

    private func evaluate(
        frames: [FrameCapture],
        events: [NeutralCalibrationEvent]
    ) -> NeutralCalibrationResult {
        evaluator.evaluate(
            frames: frames,
            attempt: NeutralCalibrationAttemptEvidence(events: events)
        )
    }

    private func physicalTimestamps(startingAt start: TimeInterval = 0, through end: TimeInterval) -> [TimeInterval] {
        var timestamps: [TimeInterval] = []
        var timestamp = start
        while timestamp <= end + 1e-9 {
            timestamps.append(timestamp)
            timestamp += 0.11665
        }
        return timestamps
    }

    private func trackingEvents(_ timestamps: [TimeInterval]) -> [NeutralCalibrationEvent] {
        timestamps.map { event(timestamp: $0) }
    }

    private func event(
        timestamp: TimeInterval,
        state: FaceTrackingObservationState = .tracking,
        faceCount: Int = 1,
        cameraState: String = "Tracking"
    ) -> NeutralCalibrationEvent {
        NeutralCalibrationEvent(
            sourceTimestamp: timestamp,
            faceIsPresent: state == .tracking,
            visibleFaceCount: faceCount,
            faceTrackingState: state,
            hasBlendshapeMeasurements: state == .tracking,
            cameraTrackingState: cameraState
        )
    }

    private func rawFrame(index: Int, timestamp: TimeInterval, value: Double) -> RawFrameCapture {
        RawFrameCapture(
            id: TestFixtures.deterministicUUID(900 + index), recordingID: nil, frameIndex: index,
            sourceTimestamp: timestamp, taskType: .neutralRest, repetitionIndex: 1,
            rawBlendshapes: ["a": value], faceTransform: nil,
            headPose: HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
            faceIsPresent: true, visibleFaceCount: 1, faceTrackingState: .tracking,
            faceCenter: CGPoint(x: 0.5, y: 0.5), faceScale: 0.35,
            cameraTrackingStateAtCapture: "Tracking", isNeutralPhase: true,
            validationImageReference: nil
        )
    }

    private func frame(
        index: Int,
        timestamp: TimeInterval,
        value: Double,
        flags: [QCFlag] = [],
        valid: Bool = true
    ) -> FrameCapture {
        TestFixtures.frame(index: index, timestamp: timestamp, task: .neutralRest,
                           raw: ["a": value], flags: flags, valid: valid)
    }
}
