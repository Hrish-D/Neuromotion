import CoreGraphics
import Foundation
import simd
import XCTest
@testable import Facework

@MainActor
final class SynchronizedFaceObservationTests: XCTestCase {
    func testEnvelopeCarriesMeasurementAndImageFromOneSyntheticSourceFrame() {
        let input = snapshotInput(timestamp: 10, value: 0.25)
        let envelope = SynchronizedFaceObservationBuilder.make(
            event: .faceUpdate(input),
            validationImageSource: ValidationImageSource(
                sourceTimestamp: 10,
                payload: .encodedImageData(Data("image-A".utf8), identifier: "image-A")
            ),
            frameCameraTrackingState: "normal"
        )

        XCTAssertEqual(envelope.observation.sourceTimestamp, 10)
        XCTAssertEqual(envelope.observation.rawBlendshapes, ["jawOpen": 0.25])
        XCTAssertEqual(envelope.validationImageSource?.sourceTimestamp, 10)
        XCTAssertEqual(envelope.validationImageSource?.payload.testIdentifier, "image-A")
        XCTAssertEqual(envelope.frameCameraTrackingState, "normal")
    }

    func testLaterSourceFrameCannotReplaceAcceptedImage() {
        let provider = SyntheticFaceObservationProvider()
        let collector = FaceObservationCollector(provider: provider, cameraTrackingState: { "Tracking" })
        var samples: [CollectedFaceObservation] = []
        collector.start(mode: .task(task: .smileTeeth, repetitionIndex: 1)) {
            samples.append($0)
        }

        provider.emit(synchronized(timestamp: 10.000, value: 0.1, imageID: "image-A"))
        provider.emit(synchronized(timestamp: 10.016, value: 0.9, imageID: "image-B"))

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].observation.rawBlendshapes, ["jawOpen": 0.1])
        XCTAssertEqual(samples[0].validationImageSource?.payload.testIdentifier, "image-A")
    }

    func testSamplingGateRejectsDuplicateDecreasingAndTooCloseImageCandidates() {
        let provider = SyntheticFaceObservationProvider()
        let collector = FaceObservationCollector(provider: provider, cameraTrackingState: { "Tracking" })
        var samples: [CollectedFaceObservation] = []
        collector.start(mode: .neutral) { samples.append($0) }

        provider.emit(synchronized(timestamp: 20, value: 0.1, imageID: "first"))
        provider.emit(synchronized(timestamp: 20, value: 0.2, imageID: "duplicate"))
        provider.emit(synchronized(timestamp: 19.9, value: 0.3, imageID: "decreasing"))
        provider.emit(synchronized(timestamp: 20.05, value: 0.4, imageID: "too-close"))
        provider.emit(synchronized(timestamp: 20.1, value: 0.5, imageID: "second"))

        XCTAssertEqual(samples.map(\.observation.sourceTimestamp), [20, 20.1])
        XCTAssertEqual(samples.compactMap { $0.validationImageSource?.payload.testIdentifier }, ["first", "second"])
    }

    func testStopAndRestartKeepImageSourcesIsolatedByRecording() {
        let provider = SyntheticFaceObservationProvider()
        let collector = FaceObservationCollector(provider: provider, cameraTrackingState: { "Tracking" })
        var samples: [CollectedFaceObservation] = []
        let firstID = collector.start(mode: .task(task: .browRaise, repetitionIndex: 1)) { samples.append($0) }
        provider.emit(synchronized(timestamp: 1, value: 0.1, imageID: "rep-1"))
        collector.stop(recordingID: firstID)
        provider.emit(synchronized(timestamp: 2, value: 0.2, imageID: "late"))
        let secondID = collector.start(mode: .task(task: .browRaise, repetitionIndex: 2)) { samples.append($0) }
        provider.emit(synchronized(timestamp: 2.01, value: 0.3, imageID: "rep-2"))

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(samples.compactMap { $0.validationImageSource?.payload.testIdentifier }, ["rep-1", "rep-2"])
        XCTAssertEqual(samples.map(\.mode), [
            .task(task: .browRaise, repetitionIndex: 1),
            .task(task: .browRaise, repetitionIndex: 2)
        ])
    }

    func testPromptNineNoFaceEventStillArrivesBeforeSamplingGateWithoutImage() {
        let provider = SyntheticFaceObservationProvider()
        let collector = FaceObservationCollector(provider: provider, cameraTrackingState: { "Tracking" })
        var events: [CollectedFaceObservation] = []
        var samples: [CollectedFaceObservation] = []
        collector.start(mode: .neutral, eventHandler: { events.append($0) }) { samples.append($0) }

        provider.emit(synchronized(timestamp: 1, value: 0.1, imageID: "tracked"))
        provider.emit(noFace(timestamp: 1.01))

        XCTAssertEqual(events.map(\.observation.trackingState), [.tracking, .noFace])
        XCTAssertEqual(samples.map(\.observation.trackingState), [.tracking])
        XCTAssertNil(events.last?.validationImageSource)
    }

    func testValidationImagePolicyPreservesStrideAndNames() {
        XCTAssertEqual((0...20).filter(ValidationImageCapturePolicy.shouldCapture), [0, 10, 20])
        XCTAssertEqual(
            ValidationImageCapturePolicy.fileStem(task: .smileTeeth, repetitionIndex: 2, frameIndex: 10),
            "validation_smileTeeth_rep_2_frame_0010"
        )
    }

    private func synchronized(
        timestamp: TimeInterval,
        value: Double,
        imageID: String
    ) -> SynchronizedFaceObservation {
        SynchronizedFaceObservationBuilder.make(
            event: .faceUpdate(snapshotInput(timestamp: timestamp, value: value)),
            validationImageSource: ValidationImageSource(
                sourceTimestamp: timestamp,
                payload: .encodedImageData(Data(imageID.utf8), identifier: imageID)
            )
        )
    }

    private func snapshotInput(timestamp: TimeInterval, value: Double) -> FaceTrackingSnapshotInput {
        FaceTrackingSnapshotInput(
            sourceTimestamp: timestamp,
            rawBlendshapes: ["jawOpen": value],
            faceTransform: simd_float4x4(1),
            faceIsPresent: true,
            visibleFaceCount: 1,
            trackingState: .tracking,
            faceCenter: CGPoint(x: 0.5, y: 0.5),
            faceScale: 0.35
        )
    }

    private func noFace(timestamp: TimeInterval) -> FaceTrackingObservation {
        FaceTrackingObservation(
            sourceTimestamp: timestamp,
            rawBlendshapes: [:],
            faceTransform: nil,
            headPose: nil,
            faceIsPresent: false,
            visibleFaceCount: 0,
            trackingState: .noFace,
            faceCenter: .zero,
            faceScale: 0
        )
    }
}
