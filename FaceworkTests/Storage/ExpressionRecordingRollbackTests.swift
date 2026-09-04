import XCTest
@testable import Facework

@MainActor
final class ExpressionRecordingRollbackTests: XCTestCase {
    private static var retainedStores: [SessionStore] = []

    func testRollbackRemovesOnlyAbortedRecordingAndIsIdempotent() throws {
        let completedID = TestFixtures.deterministicUUID(910)
        let invalidID = TestFixtures.deterministicUUID(911)
        let abortedID = TestFixtures.deterministicUUID(912)
        let topology = makeTopology()
        let completed = makeFrame(recordingID: completedID, index: 0, repetition: 1, valid: true)
        let invalid = makeFrame(recordingID: invalidID, index: 0, repetition: 2, valid: false)
        let completedInvalidRepetition = TestFixtures.repetition(index: 2, task: .browRaise, valid: false)
        let aborted = makeFrame(recordingID: abortedID, index: 0, repetition: 3, valid: true)
        var accumulator = FaceMeshSessionAccumulator()
        [completed, invalid, aborted].forEach {
            accumulator.record(rawFrame: $0.raw, snapshot: makeSnapshot(for: $0.raw, topology: topology))
        }

        var retained = accumulator.removingRecords(
            recordingID: abortedID,
            from: [completed, invalid, aborted]
        )
        retained = accumulator.removingRecords(recordingID: abortedID, from: retained)

        XCTAssertEqual(retained.map(\.raw.recordingID), [completedID, invalidID])
        XCTAssertFalse(completedInvalidRepetition.valid)
        XCTAssertEqual(Set(accumulator.frames.map(\.recordingID)), [completedID, invalidID])
        XCTAssertTrue(accumulator.unavailableFrames.allSatisfy { $0.recordingID != abortedID })
        XCTAssertEqual(FaceMeshExportValidator.validate(
            rawFrames: retained.map(\.raw), meshFrames: accumulator.frames,
            unavailableFrames: accumulator.unavailableFrames, topology: accumulator.topology
        ), [])
        XCTAssertFalse(invalid.isValidFrame)
    }

    func testRetryAfterRollbackValidatesAndSessionStoreSaves() throws {
        let abortedID = TestFixtures.deterministicUUID(920)
        let retryID = TestFixtures.deterministicUUID(921)
        let topology = makeTopology()
        let aborted = makeFrame(recordingID: abortedID, index: 0, repetition: 1, valid: true)
        let retry = makeFrame(recordingID: retryID, index: 0, repetition: 1, valid: true)
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: aborted.raw, snapshot: makeSnapshot(for: aborted.raw, topology: topology))
        let retainedAfterAbort = accumulator.removingRecords(recordingID: abortedID, from: [aborted])
        XCTAssertTrue(retainedAfterAbort.isEmpty)
        accumulator.record(rawFrame: retry.raw, snapshot: makeSnapshot(for: retry.raw, topology: topology))

        XCTAssertEqual(FaceMeshExportValidator.validate(
            rawFrames: [retry.raw], meshFrames: accumulator.frames,
            unavailableFrames: accumulator.unavailableFrames, topology: accumulator.topology
        ), [])

        let metadata = meshMetadata()
        let store = SessionStore()
        Self.retainedStores.append(store)
        let urls = try store.save(
            metadata: metadata, config: [.browRaise: .default(for: .browRaise)], frames: [retry],
            meshFrames: accumulator.frames, unavailableMeshFrames: accumulator.unavailableFrames,
            faceMeshTopology: accumulator.topology, repetitions: [], summary: TestFixtures.summary(metadata: metadata)
        )
        XCTAssertNotNil(urls.first { $0.pathExtension == "zip" })
        for url in urls where url.pathExtension == "zip" { try? FileManager.default.removeItem(at: url) }
        if let folder = urls.first?.deletingLastPathComponent() { try? FileManager.default.removeItem(at: folder) }
    }

    private func makeFrame(recordingID: UUID, index: Int, repetition: Int, valid: Bool) -> FrameCapture {
        let raw = RawFrameCapture(
            id: UUID(), recordingID: recordingID, frameIndex: index, sourceTimestamp: Double(repetition),
            taskType: .browRaise, repetitionIndex: repetition, rawBlendshapes: ["browInnerUp": 0.5],
            faceTransform: nil, headPose: nil, faceIsPresent: true, visibleFaceCount: 1,
            faceTrackingState: .tracking, faceCenter: .zero, faceScale: 1,
            cameraTrackingStateAtCapture: "normal", isNeutralPhase: false,
            validationImageReference: nil
        )
        return FrameCapture(raw: raw, analysis: FrameAnalysis(
            normalizedBlendshapes: raw.rawBlendshapes, smoothedBlendshapes: raw.rawBlendshapes,
            qcFlags: valid ? [] : [.trackingLost], isValidFrame: valid
        ))
    }

    private func makeTopology() -> FaceMeshTopology {
        FaceMeshTopology(vertexCount: 3, triangleCount: 1, triangleIndices: [0, 1, 2],
                         textureCoordinates: [.init(u: 0, v: 0), .init(u: 1, v: 0), .init(u: 0, v: 1)])
    }

    private func makeSnapshot(for raw: RawFrameCapture, topology: FaceMeshTopology) -> FaceMeshSnapshot {
        FaceMeshSnapshot(sourceTimestamp: raw.sourceTimestamp, topology: topology,
                         vertices: [.init(x: 0, y: 0, z: 0), .init(x: 1, y: 0, z: 0), .init(x: 0, y: 1, z: 0)])
    }

    private func meshMetadata() -> SessionMetadata {
        let base = TestFixtures.metadata(participantID: "ROLLBACK-TEST")
        return SessionMetadata(
            sessionID: UUID().uuidString, studyID: base.studyID, participantID: base.participantID,
            raterID: base.raterID, appVersion: base.appVersion, deviceModel: base.deviceModel,
            osVersion: base.osVersion, sessionDate: base.sessionDate, notes: base.notes,
            affectedSide: base.affectedSide, sessionLabel: base.sessionLabel,
            appMarketingVersion: base.appMarketingVersion, appBuildNumber: base.appBuildNumber,
            rawDataSchemaVersion: base.rawDataSchemaVersion, analysisAlgorithmVersion: base.analysisAlgorithmVersion,
            captureProtocolVersion: base.captureProtocolVersion, meshCaptureVersion: "test-mesh",
            landmarkConfigurationVersion: base.landmarkConfigurationVersion,
            deviceModelIdentifier: base.deviceModelIdentifier, operatingSystemName: base.operatingSystemName,
            operatingSystemVersion: base.operatingSystemVersion
        )
    }
}
