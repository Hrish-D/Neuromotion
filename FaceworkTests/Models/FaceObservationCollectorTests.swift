import Combine
import XCTest
@testable import Facework

@MainActor
final class FaceObservationCollectorTests: XCTestCase {
    func testObservationsOutsideActiveWindowAreIgnored() {
        let context = makeContext()

        context.provider.emit(observation(timestamp: 1))

        XCTAssertTrue(context.samples.isEmpty)
    }

    func testNeutralCollectionAcceptsObservationInNeutralMode() {
        let context = makeContext()
        context.start(mode: .neutral)

        context.provider.emit(observation(timestamp: 1))

        XCTAssertEqual(context.samples.count, 1)
        XCTAssertEqual(context.samples.first?.mode, .neutral)
    }

    func testTaskCollectionCarriesTaskAndRepetitionMetadataIntoFrame() {
        let context = makeContext()
        let viewModel = TaskExecutionViewModel()
        context.start(mode: .task(task: .smileTeeth, repetitionIndex: 3)) {
            viewModel.appendLiveFrame(
                collectedObservation: $0,
                baseline: [:],
                isNeutralPhase: false
            )
        }

        context.provider.emit(observation(timestamp: 2))

        XCTAssertEqual(viewModel.captureFrames.first?.taskType, .smileTeeth)
        XCTAssertEqual(viewModel.captureFrames.first?.repetitionIndex, 3)
    }

    func testStoredFrameValuesComeFromOneObservation() {
        let context = makeContext(trackingState: "normal")
        let viewModel = TaskExecutionViewModel()
        let source = observation(
            timestamp: 4.25,
            blendshapes: ["jawOpen": 0.42],
            pose: HeadPose(yawDegrees: 2, pitchDegrees: 3, rollDegrees: 4),
            faceCount: 1,
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 0.35
        )
        context.start(mode: .task(task: .cheekPuff, repetitionIndex: 2)) {
            viewModel.appendLiveFrame(
                collectedObservation: $0,
                baseline: ["jawOpen": 0.02],
                isNeutralPhase: false
            )
        }

        context.provider.emit(source)

        let frame = viewModel.captureFrames.first
        XCTAssertEqual(frame?.timestamp, 4.25)
        XCTAssertEqual(frame?.rawBlendshapes, ["jawOpen": 0.42])
        XCTAssertEqual(frame?.normalizedBlendshapes["jawOpen"] ?? .nan, 0.40, accuracy: 0.000_001)
        XCTAssertEqual(frame?.headPose, source.headPose)
        XCTAssertEqual(frame?.trackingState, "normal")
        XCTAssertFalse(frame?.qcFlags.contains(.multipleFaces) ?? true)
        XCTAssertFalse(frame?.qcFlags.contains(.poorFraming) ?? true)
    }

    func testObservationOrderIsPreserved() {
        let context = makeContext()
        context.start(mode: .neutral)

        [1.0, 1.1, 1.2].forEach { context.provider.emit(observation(timestamp: $0)) }

        XCTAssertEqual(context.samples.map(\.observation.sourceTimestamp), [1.0, 1.1, 1.2])
    }

    func testStopPreventsLaterAppend() {
        let context = makeContext()
        let recordingID = context.start(mode: .neutral)
        context.provider.emit(observation(timestamp: 1))

        context.collector.stop(recordingID: recordingID)
        context.provider.emit(observation(timestamp: 2))

        XCTAssertEqual(context.samples.map(\.observation.sourceTimestamp), [1])
    }

    func testRestartForNextRepetitionDoesNotRetainPriorState() {
        let context = makeContext()
        context.start(mode: .task(task: .browRaise, repetitionIndex: 1))
        context.provider.emit(observation(timestamp: 10))

        context.start(mode: .task(task: .browRaise, repetitionIndex: 2))
        context.provider.emit(observation(timestamp: 10.01))

        XCTAssertEqual(context.samples.map(\.mode), [
            .task(task: .browRaise, repetitionIndex: 1),
            .task(task: .browRaise, repetitionIndex: 2)
        ])
    }

    func testNeutralAndTaskModesRemainDistinct() {
        let context = makeContext()
        context.start(mode: .neutral)
        context.provider.emit(observation(timestamp: 1))
        context.start(mode: .task(task: .eyeClosure, repetitionIndex: 1))
        context.provider.emit(observation(timestamp: 2))

        XCTAssertEqual(context.samples.map(\.mode), [
            .neutral,
            .task(task: .eyeClosure, repetitionIndex: 1)
        ])
    }

    func testSamplingPreservesPointOneSecondCadence() {
        let context = makeContext()
        context.start(mode: .neutral)

        [1.0, 1.05, 1.1, 1.19, 1.2].forEach {
            context.provider.emit(observation(timestamp: $0))
        }

        XCTAssertEqual(context.samples.map(\.observation.sourceTimestamp), [1.0, 1.1, 1.2])
    }

    func testSamplingUsesObservationTimestampNotWallClock() {
        let context = makeContext()
        context.start(mode: .neutral)

        context.provider.emit(observation(timestamp: 50))
        context.provider.emit(observation(timestamp: 50.01))
        context.provider.emit(observation(timestamp: 50.11))

        XCTAssertEqual(context.samples.map(\.observation.sourceTimestamp), [50, 50.11])
    }

    func testOneObservationCannotCreateDuplicateFrame() {
        let context = makeContext()
        context.start(mode: .neutral)

        context.provider.emit(observation(timestamp: 1))

        XCTAssertEqual(context.samples.count, 1)
    }

    func testFrameConstructionDoesNotUseManagerCompatibilityValues() {
        let context = makeContext(trackingState: "limited")
        let viewModel = TaskExecutionViewModel()
        context.start(mode: .neutral) {
            viewModel.appendLiveFrame(
                collectedObservation: $0,
                baseline: [:],
                isNeutralPhase: true
            )
        }

        context.provider.emit(
            observation(
                timestamp: 7,
                blendshapes: ["eyeBlinkLeft": 0.12],
                pose: HeadPose(yawDegrees: 1, pitchDegrees: 2, rollDegrees: 3)
            )
        )

        XCTAssertEqual(viewModel.captureFrames.first?.rawBlendshapes, ["eyeBlinkLeft": 0.12])
        XCTAssertEqual(viewModel.captureFrames.first?.timestamp, 7)
        XCTAssertEqual(viewModel.captureFrames.first?.trackingState, "limited")
    }

    func testFaceLossAndMultipleFacesKeepExistingQCSemantics() {
        let context = makeContext()
        let viewModel = TaskExecutionViewModel()
        context.start(mode: .neutral) {
            viewModel.appendLiveFrame(
                collectedObservation: $0,
                baseline: [:],
                isNeutralPhase: true
            )
        }

        context.provider.emit(unavailableObservation(timestamp: 1, state: .noFace, faceCount: 0))
        context.provider.emit(unavailableObservation(timestamp: 1.1, state: .multipleFaces, faceCount: 2))

        XCTAssertTrue(viewModel.captureFrames[0].qcFlags.contains(.noFace))
        XCTAssertTrue(viewModel.captureFrames[0].qcFlags.contains(.trackingLost))
        XCTAssertTrue(viewModel.captureFrames[1].qcFlags.contains(.multipleFaces))
    }

    func testReacquisitionResumesEligibleCapture() {
        let context = makeContext()
        context.start(mode: .neutral)

        context.provider.emit(unavailableObservation(timestamp: 1, state: .noFace, faceCount: 0))
        context.provider.emit(observation(timestamp: 1.1))

        XCTAssertEqual(context.samples.map(\.observation.trackingState), [.noFace, .tracking])
    }

    func testCollectorIsMainActorIsolated() {
        let context = makeContext()
        acceptMainActorCollector(context.collector)
    }

    func testSyntheticProviderDrivesCollectorWithoutARSession() {
        let context = makeContext()
        context.start(mode: .neutral)

        context.provider.emit(observation(timestamp: 123))

        XCTAssertEqual(context.samples.first?.observation.sourceTimestamp, 123)
    }

    func testStoppingBeforeFinalizationExcludesLateObservation() {
        let context = makeContext()
        context.start(mode: .task(task: .lipPucker, repetitionIndex: 1))
        context.provider.emit(observation(timestamp: 1))
        context.collector.stop()
        let finalized = context.samples

        context.provider.emit(observation(timestamp: 2))

        XCTAssertEqual(finalized.count, 1)
        XCTAssertEqual(context.samples.count, finalized.count)
    }

    func testWrongRecordingIDCannotStopCurrentRepetition() {
        let context = makeContext()
        context.start(mode: .task(task: .smileClosed, repetitionIndex: 2))

        context.collector.stop(recordingID: UUID())
        context.provider.emit(observation(timestamp: 1))

        XCTAssertEqual(context.samples.count, 1)
    }

    private func acceptMainActorCollector(_ collector: FaceObservationCollector) {
        _ = collector
    }

    private func makeContext(
        trackingState: String = "normal"
    ) -> CollectorTestContext {
        CollectorTestContext(trackingState: trackingState)
    }

    private func observation(
        timestamp: TimeInterval,
        blendshapes: [String: Double] = ["mouthSmileLeft": 0.2],
        pose: HeadPose = HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
        faceCount: Int = 1,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: Double = 0.35
    ) -> FaceTrackingObservation {
        FaceTrackingObservation(
            sourceTimestamp: timestamp,
            rawBlendshapes: blendshapes,
            faceTransform: nil,
            headPose: pose,
            faceIsPresent: true,
            visibleFaceCount: faceCount,
            trackingState: .tracking,
            faceCenter: center,
            faceScale: scale
        )
    }

    private func unavailableObservation(
        timestamp: TimeInterval,
        state: FaceTrackingObservationState,
        faceCount: Int
    ) -> FaceTrackingObservation {
        FaceTrackingObservation(
            sourceTimestamp: timestamp,
            rawBlendshapes: [:],
            faceTransform: nil,
            headPose: nil,
            faceIsPresent: false,
            visibleFaceCount: faceCount,
            trackingState: state,
            faceCenter: .zero,
            faceScale: 0
        )
    }
}

@MainActor
private struct CollectorTestContext {
    let provider = SyntheticFaceObservationProvider()
    let collector: FaceObservationCollector
    private let sampleStore = CollectorSampleStore()

    var samples: [CollectedFaceObservation] {
        sampleStore.samples
    }

    init(trackingState: String) {
        collector = FaceObservationCollector(
            provider: provider,
            cameraTrackingState: { trackingState }
        )
    }

    @discardableResult
    func start(
        mode: FaceObservationCollectionMode,
        handler: ((CollectedFaceObservation) -> Void)? = nil
    ) -> UUID {
        collector.start(mode: mode) { sample in
            sampleStore.samples.append(sample)
            handler?(sample)
        }
    }
}

nonisolated private final class CollectorSampleStore: @unchecked Sendable {
    @MainActor var samples: [CollectedFaceObservation] = []
}
