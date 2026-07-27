import Combine
import simd
import XCTest
@testable import Facework

@MainActor
final class FaceTrackingObservationTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testOneSnapshotInputProducesExactlyOneObservation() {
        let provider = SyntheticFaceObservationProvider()
        var received: [FaceTrackingObservation] = []
        provider.observations.sink { received.append($0) }.store(in: &cancellables)

        provider.emit(makeObservation(timestamp: 1))

        XCTAssertEqual(received.count, 1)
    }

    func testObservationValuesComeFromOneSnapshotInput() {
        let transform = transformWithRotation(zRadians: .pi / 4)
        let observation = FaceTrackingObservationBuilder.make(
            from: FaceTrackingSnapshotInput(
                sourceTimestamp: 12.5,
                rawBlendshapes: ["mouthSmileLeft": 0.4],
                faceTransform: transform,
                faceIsPresent: true,
                visibleFaceCount: 1,
                trackingState: .tracking,
                faceCenter: CGPoint(x: 0.5, y: 0.5),
                faceScale: 0.35
            )
        )

        XCTAssertEqual(observation.sourceTimestamp, 12.5)
        XCTAssertEqual(observation.rawBlendshapes, ["mouthSmileLeft": 0.4])
        XCTAssertEqual(observation.faceTransform?.columns.0, transform.columns.0)
        XCTAssertEqual(observation.faceTransform?.columns.1, transform.columns.1)
        XCTAssertEqual(observation.faceIsPresent, true)
        XCTAssertEqual(observation.visibleFaceCount, 1)
        XCTAssertEqual(observation.trackingState, .tracking)
        XCTAssertEqual(observation.faceCenter, CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(observation.faceScale, 0.35)
    }

    func testSourceTimestampIsCopiedExactly() {
        XCTAssertEqual(makeObservation(timestamp: 123.456).sourceTimestamp, 123.456)
    }

    func testBlendshapeDictionaryIsAnImmutableValueSnapshot() {
        var source = ["eyeBlinkLeft": 0.25]
        let observation = FaceTrackingObservationBuilder.make(
            from: input(timestamp: 1, blendshapes: source)
        )

        source["eyeBlinkLeft"] = 0.9
        source["eyeBlinkRight"] = 0.7

        XCTAssertEqual(observation.rawBlendshapes, ["eyeBlinkLeft": 0.25])
    }

    func testTransformAndPoseAreCopiedFromTheSameInput() {
        var transform = transformWithRotation(zRadians: .pi / 2)
        let expectedTransform = transform
        let observation = FaceTrackingObservationBuilder.make(
            from: input(timestamp: 2, transform: transform)
        )

        transform = matrix_identity_float4x4

        XCTAssertEqual(observation.faceTransform?.columns.0, expectedTransform.columns.0)
        XCTAssertEqual(observation.faceTransform?.columns.1, expectedTransform.columns.1)
        XCTAssertEqual(observation.headPose, FaceTrackingObservationBuilder.poseFromTransform(expectedTransform))
        XCTAssertNotEqual(observation.faceTransform?.columns.0, transform.columns.0)
    }

    func testProductionSingleFaceUpdateEmitsExactlyOneTrackingObservation() {
        let observations = processProductionEvents([
            .faceUpdate(input(timestamp: 1))
        ])

        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations[0].trackingState, .tracking)
    }

    func testProductionEmptyUpdateEmitsExactlyOneNoFaceObservation() {
        let observations = processProductionEvents([
            .noFaceUpdate(sourceTimestamp: 2)
        ])

        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations[0].trackingState, .noFace)
    }

    func testProductionMultipleFaceUpdateEmitsExactlyOneDefensiveObservation() {
        let observations = processProductionEvents([
            .multipleFaceUpdate(sourceTimestamp: 3, updatedFaceAnchorCount: 2)
        ])

        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations[0].trackingState, .multipleFaces)
        XCTAssertEqual(observations[0].visibleFaceCount, 2)
    }

    func testProductionRemovalEmitsExactlyOneNoFaceObservation() {
        let observations = processProductionEvents([
            .faceRemoved(sourceTimestamp: 4)
        ])

        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations[0].trackingState, .noFace)
        XCTAssertFalse(observations[0].faceIsPresent)
    }

    func testProductionRemovalDoesNotEmitContradictoryTrackingObservation() {
        let observations = processProductionEvents([
            .faceRemoved(sourceTimestamp: 5)
        ])

        XCTAssertFalse(observations.contains { $0.trackingState == .tracking })
        XCTAssertEqual(observations.map(\.trackingState), [.noFace])
    }

    func testProductionPathDoesNotEmitTrackingAfterRemovalWithoutNewUpdate() {
        let observations = processProductionEvents([
            .faceUpdate(input(timestamp: 1)),
            .faceRemoved(sourceTimestamp: 2)
        ])

        XCTAssertEqual(observations.map(\.trackingState), [.tracking, .noFace])
    }

    func testProductionReacquisitionEmitsNewTrackingObservation() {
        let observations = processProductionEvents([
            .faceUpdate(input(timestamp: 1)),
            .faceRemoved(sourceTimestamp: 2),
            .faceUpdate(input(timestamp: 3, blendshapes: ["jawOpen": 0.7]))
        ])

        XCTAssertEqual(observations.map(\.trackingState), [.tracking, .noFace, .tracking])
        XCTAssertEqual(observations.last?.rawBlendshapes, ["jawOpen": 0.7])
    }

    func testProductionEventsPreserveSourceOrder() {
        let observations = processProductionEvents([
            .faceUpdate(input(timestamp: 10)),
            .noFaceUpdate(sourceTimestamp: 11),
            .multipleFaceUpdate(sourceTimestamp: 12, updatedFaceAnchorCount: 2),
            .faceRemoved(sourceTimestamp: 13),
            .faceUpdate(input(timestamp: 14))
        ])

        XCTAssertEqual(observations.map(\.sourceTimestamp), [10, 11, 12, 13, 14])
    }

    func testProductionEventProcessorEmitsOncePerEvent() {
        let observation = FaceTrackingEventProcessor.observation(
            for: .faceRemoved(sourceTimestamp: 20)
        )

        XCTAssertEqual(observation.trackingState, .noFace)
    }

    func testSyntheticProviderPreservesEmissionOrder() {
        let provider = SyntheticFaceObservationProvider()
        var timestamps: [TimeInterval] = []
        provider.observations.sink { timestamps.append($0.sourceTimestamp) }.store(in: &cancellables)

        [3.0, 4.0, 5.0].forEach { provider.emit(makeObservation(timestamp: $0)) }

        XCTAssertEqual(timestamps, [3, 4, 5])
    }

    func testRemovalProducesExplicitUnavailableObservation() {
        let provider = SyntheticFaceObservationProvider()
        var states: [FaceTrackingObservationState] = []
        provider.observations.sink { states.append($0.trackingState) }.store(in: &cancellables)

        provider.emit(makeObservation(timestamp: 1))
        provider.emit(makeUnavailableObservation(timestamp: 2))

        XCTAssertEqual(states, [.tracking, .noFace])
    }

    func testNoRegularObservationAppearsAfterRemovalUntilNewValidInput() {
        let provider = SyntheticFaceObservationProvider()
        var observations: [FaceTrackingObservation] = []
        provider.observations.sink { observations.append($0) }.store(in: &cancellables)

        provider.emit(makeObservation(timestamp: 1))
        provider.emit(makeUnavailableObservation(timestamp: 2))

        XCTAssertEqual(observations.last?.trackingState, .noFace)
        XCTAssertFalse(observations.dropFirst(2).contains { $0.trackingState == .tracking })

        provider.emit(makeObservation(timestamp: 3))
        XCTAssertEqual(observations.last?.trackingState, .tracking)
    }

    func testSyntheticProviderDoesNotRequireARSession() {
        let provider = SyntheticFaceObservationProvider()
        var timestamp: TimeInterval?
        provider.observations.sink { timestamp = $0.sourceTimestamp }.store(in: &cancellables)

        provider.emit(makeObservation(timestamp: 44))

        XCTAssertEqual(timestamp, 44)
    }

    func testCompatibilityPropertiesComeFromSameObservation() {
        let manager = FaceTrackingManager()
        let observation = makeObservation(timestamp: 8, blendshapes: ["jawOpen": 0.6])

        manager.receive(observation)

        XCTAssertEqual(manager.latestObservation?.sourceTimestamp, 8)
        XCTAssertEqual(manager.latestTimestamp, observation.sourceTimestamp)
        XCTAssertEqual(manager.latestBlendshapes, observation.rawBlendshapes)
        XCTAssertEqual(manager.latestPose, observation.headPose)
        XCTAssertEqual(manager.faceIsPresent, observation.faceIsPresent)
        XCTAssertEqual(manager.visibleFaceCount, observation.visibleFaceCount)
        XCTAssertEqual(manager.faceCenter, observation.faceCenter)
        XCTAssertEqual(manager.faceScale, observation.faceScale)
        XCTAssertEqual(manager.trackingStateDescription, "Tracking")
    }

    func testFaceLossPreservesPriorSignalCompatibilityState() {
        let manager = FaceTrackingManager()
        manager.receive(makeObservation(timestamp: 1, blendshapes: ["jawOpen": 0.6]))

        manager.receive(makeUnavailableObservation(timestamp: 2))

        XCTAssertEqual(manager.latestTimestamp, 2)
        XCTAssertEqual(manager.latestBlendshapes, ["jawOpen": 0.6])
        XCTAssertFalse(manager.faceIsPresent)
        XCTAssertEqual(manager.visibleFaceCount, 0)
        XCTAssertEqual(manager.trackingStateDescription, "No face")
        XCTAssertEqual(manager.latestObservation?.trackingState, .noFace)
    }

    func testPublicationOccursOnMainActor() {
        let manager = FaceTrackingManager()
        var publishedOnMainThread = false
        manager.observations.sink { _ in
            publishedOnMainThread = Thread.isMainThread
        }.store(in: &cancellables)

        manager.receive(makeObservation(timestamp: 1))

        XCTAssertTrue(publishedOnMainThread)
        acceptMainActorProvider(manager)
    }

    private func acceptMainActorProvider(_ provider: any FaceObservationProviding) {
        _ = provider.observations
    }

    private func input(
        timestamp: TimeInterval,
        blendshapes: [String: Double] = ["mouthSmileLeft": 0.2],
        transform: simd_float4x4 = matrix_identity_float4x4
    ) -> FaceTrackingSnapshotInput {
        FaceTrackingSnapshotInput(
            sourceTimestamp: timestamp,
            rawBlendshapes: blendshapes,
            faceTransform: transform,
            faceIsPresent: true,
            visibleFaceCount: 1,
            trackingState: .tracking,
            faceCenter: CGPoint(x: 0.5, y: 0.5),
            faceScale: 0.35
        )
    }

    private func makeObservation(
        timestamp: TimeInterval,
        blendshapes: [String: Double] = ["mouthSmileLeft": 0.2]
    ) -> FaceTrackingObservation {
        FaceTrackingObservationBuilder.make(
            from: input(timestamp: timestamp, blendshapes: blendshapes)
        )
    }

    private func makeUnavailableObservation(timestamp: TimeInterval) -> FaceTrackingObservation {
        FaceTrackingObservationBuilder.make(
            from: FaceTrackingSnapshotInput(
                sourceTimestamp: timestamp,
                rawBlendshapes: [:],
                faceTransform: nil,
                faceIsPresent: false,
                visibleFaceCount: 0,
                trackingState: .noFace,
                faceCenter: .zero,
                faceScale: 0
            )
        )
    }

    private func processProductionEvents(
        _ events: [FaceTrackingCallbackEvent]
    ) -> [FaceTrackingObservation] {
        events.map(FaceTrackingEventProcessor.observation(for:))
    }

    private func transformWithRotation(zRadians: Float) -> simd_float4x4 {
        let cosine = cos(zRadians)
        let sine = sin(zRadians)
        return simd_float4x4(
            SIMD4(cosine, sine, 0, 0),
            SIMD4(-sine, cosine, 0, 0),
            SIMD4(0, 0, 1, 0),
            SIMD4(0, 0, 0, 1)
        )
    }
}
