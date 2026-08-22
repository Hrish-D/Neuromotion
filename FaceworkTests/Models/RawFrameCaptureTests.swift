import CoreGraphics
import simd
import XCTest
@testable import Facework

@MainActor
final class RawFrameCaptureTests: XCTestCase {
    func testSyntheticObservationBuildsCompleteRawFrame() throws {
        let transform = simd_float4x4(
            SIMD4(1, 2, 3, 4), SIMD4(5, 6, 7, 8),
            SIMD4(9, 10, 11, 12), SIMD4(13, 14, 15, 16)
        )
        let observation = FaceTrackingObservation(
            sourceTimestamp: 12.345,
            rawBlendshapes: ["jawOpen": 0.42],
            faceTransform: transform,
            headPose: HeadPose(yawDegrees: 1, pitchDegrees: 2, rollDegrees: 3),
            faceIsPresent: true,
            visibleFaceCount: 1,
            trackingState: .tracking,
            faceCenter: CGPoint(x: 0.4, y: 0.6),
            faceScale: 0.35
        )
        let recordingID = TestFixtures.deterministicUUID(700)
        let collected = CollectedFaceObservation(
            recordingID: recordingID,
            mode: .task(task: .smileTeeth, repetitionIndex: 2),
            observation: observation,
            validationImageSource: nil,
            cameraTrackingState: "normal"
        )

        let raw = RawFrameCapture(
            collectedObservation: collected,
            frameIndex: 7,
            isNeutralPhase: false,
            validationImageAssociation: ValidationImageAssociation(
                reference: "/synthetic/validation.jpg",
                imageSourceTimestamp: 12.345,
                synchronizationStatus: .sameARFrame
            )
        )

        XCTAssertEqual(raw.recordingID, recordingID)
        XCTAssertEqual(raw.frameIndex, 7)
        XCTAssertEqual(raw.sourceTimestamp, 12.345)
        XCTAssertEqual(raw.taskType, .smileTeeth)
        XCTAssertEqual(raw.repetitionIndex, 2)
        XCTAssertEqual(raw.rawBlendshapes, ["jawOpen": 0.42])
        XCTAssertEqual(raw.faceTransform?.matrix, transform)
        XCTAssertEqual(raw.headPose, observation.headPose)
        XCTAssertEqual(raw.faceIsPresent, true)
        XCTAssertEqual(raw.visibleFaceCount, 1)
        XCTAssertEqual(raw.faceTrackingState, .tracking)
        XCTAssertEqual(raw.faceCenter, CGPoint(x: 0.4, y: 0.6))
        XCTAssertEqual(raw.faceScale, 0.35)
        XCTAssertEqual(raw.cameraTrackingStateAtCapture, "normal")
        XCTAssertEqual(raw.isNeutralPhase, false)
        XCTAssertEqual(raw.validationImageReference, "/synthetic/validation.jpg")
        XCTAssertEqual(raw.validationImageSourceTimestamp, 12.345)
        XCTAssertEqual(raw.validationImageSynchronizationStatus, .sameARFrame)
    }

    func testRawBlendshapesAreIndependentFromSourceVariable() {
        var source = ["jawOpen": 0.25]
        let raw = makeRaw(rawBlendshapes: source)

        source["jawOpen"] = 0.9

        XCTAssertEqual(raw.rawBlendshapes, ["jawOpen": 0.25])
    }

    func testRawTransformIsIndependentFromSourceVariable() throws {
        var source = matrix(translationX: 1)
        let raw = makeRaw(faceTransform: FaceTransformSnapshot(source))

        source = matrix(translationX: 9)

        XCTAssertEqual(try XCTUnwrap(raw.faceTransform).matrix.columns.3.x, 1)
        XCTAssertEqual(source.columns.3.x, 9)
    }

    func testRawModelConstructionRequiresNoProcessedValues() {
        let raw = makeRaw()

        XCTAssertEqual(raw.rawBlendshapes, ["jawOpen": 0.25])
        // FrameAnalysis owns normalized, smoothed, and QC values at compile time.
        let analysis = FrameAnalysis(
            normalizedBlendshapes: ["jawOpen": 0.2],
            smoothedBlendshapes: ["jawOpen": 0.2],
            qcFlags: [],
            isValidFrame: true
        )
        XCTAssertEqual(analysis.normalizedBlendshapes["jawOpen"], 0.2)
    }

    func testProcessingDoesNotMutateRawFrame() {
        let raw = makeRaw()
        let before = raw

        _ = FrameProcessor().process(raw: raw, baseline: ["jawOpen": 0.05], previous: nil)

        XCTAssertEqual(raw, before)
    }

    func testCurrentFrameProcessingResultsRemainEquivalent() {
        let raw = makeRaw()
        let frame = FrameProcessor().process(raw: raw, baseline: ["jawOpen": 0.05], previous: nil)

        XCTAssertEqual(frame.normalizedBlendshapes["jawOpen"] ?? .nan, 0.20, accuracy: 0.000_001)
        XCTAssertEqual(frame.smoothedBlendshapes, frame.normalizedBlendshapes)
        XCTAssertTrue(frame.isValidFrame)
        XCTAssertTrue(frame.qcFlags.isEmpty)
    }

    func testReprocessingSameRawFrameIsDeterministic() {
        let raw = makeRaw()
        let processor = FrameProcessor()

        let first = processor.process(raw: raw, baseline: ["jawOpen": 0.05], previous: nil)
        let second = processor.process(raw: raw, baseline: ["jawOpen": 0.05], previous: nil)

        XCTAssertEqual(first, second)
    }

    func testRawRoundTripPreservesEveryAcquisitionField() throws {
        let raw = makeRaw(
            faceTransform: FaceTransformSnapshot(matrix(translationX: 2)),
            validationImageReference: "/synthetic/validation.jpg"
        )

        let data = try JSONEncoder().encode(raw)
        let decoded = try JSONDecoder().decode(RawFrameCapture.self, from: data)

        XCTAssertEqual(decoded, raw)
    }

    func testLegacyFlatFrameRemainsReadableWithoutInventingUnavailableRawContext() throws {
        let legacy = TestFixtures.frame(raw: ["jawOpen": 0.3], normalized: ["jawOpen": 0.2])
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(FrameCapture.self, from: data)

        XCTAssertEqual(decoded.rawBlendshapes, ["jawOpen": 0.3])
        XCTAssertEqual(decoded.normalizedBlendshapes, ["jawOpen": 0.2])
        XCTAssertNil(decoded.raw.recordingID)
        XCTAssertNil(decoded.raw.faceTransform)
        XCTAssertNil(decoded.raw.faceTrackingState)
        XCTAssertNil(decoded.raw.faceCenter)
        XCTAssertNil(decoded.raw.faceScale)
    }

    func testCameraTrackingStateRemainsSeparateFromFaceObservationState() {
        let raw = makeRaw(faceTrackingState: .tracking, cameraTrackingState: "limited")

        XCTAssertEqual(raw.faceTrackingState, .tracking)
        XCTAssertEqual(raw.cameraTrackingStateAtCapture, "limited")
    }

    private func makeRaw(
        rawBlendshapes: [String: Double] = ["jawOpen": 0.25],
        faceTransform: FaceTransformSnapshot? = nil,
        faceTrackingState: FaceTrackingObservationState = .tracking,
        cameraTrackingState: String = "normal",
        validationImageReference: String? = nil
    ) -> RawFrameCapture {
        RawFrameCapture(
            id: TestFixtures.deterministicUUID(701),
            recordingID: TestFixtures.deterministicUUID(702),
            frameIndex: 3,
            sourceTimestamp: 10.11665,
            taskType: .smileClosed,
            repetitionIndex: 2,
            rawBlendshapes: rawBlendshapes,
            faceTransform: faceTransform,
            headPose: HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
            faceIsPresent: true,
            visibleFaceCount: 1,
            faceTrackingState: faceTrackingState,
            faceCenter: CGPoint(x: 0.5, y: 0.5),
            faceScale: 0.35,
            cameraTrackingStateAtCapture: cameraTrackingState,
            isNeutralPhase: false,
            validationImageReference: validationImageReference
        )
    }

    private func matrix(translationX: Float) -> simd_float4x4 {
        simd_float4x4(
            SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0),
            SIMD4(0, 0, 1, 0), SIMD4(translationX, 0, 0, 1)
        )
    }
}
