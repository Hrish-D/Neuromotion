import XCTest
@testable import Facework

@MainActor
final class ResearchFaceGeometryStoreTests: XCTestCase {
    func testSessionLoadDraftExportImportAndRawBytesStayUnchanged() throws {
        let fixture = try makeStoredSession()
        let store = ResearchFaceGeometryStore()
        let rawURL = fixture.directory.url.appendingPathComponent(SessionStore.rawFaceMeshFramesFileName)
        let topologyURL = fixture.directory.url.appendingPathComponent(SessionStore.faceMeshTopologyFileName)
        let rawBefore = try Data(contentsOf: rawURL)
        let topologyBefore = try Data(contentsOf: topologyURL)
        let session = try store.loadSession(at: fixture.directory.url)
        var draft = ResearchFaceGeometryConfiguration.empty(topologyID: session.topology.topologyID, name: "Synthetic Draft")
        draft.landmarks.append(FaceLandmarkDefinition(id: "test", displayName: "Test Point", source: .meshVertex(index: 2), notes: "Research only"))
        let draftURL = try store.exportDraft(draft, for: session)
        XCTAssertEqual(draftURL.lastPathComponent, ResearchFaceGeometryStore.draftFileName)
        XCTAssertEqual(try store.importDraft(from: draftURL, for: session), draft)
        XCTAssertEqual(try Data(contentsOf: rawURL), rawBefore)
        XCTAssertEqual(try Data(contentsOf: topologyURL), topologyBefore)
        XCTAssertEqual(session.metadata.landmarkConfigurationVersion, "not-active")
    }

    func testWrongTopologyImportIsRejected() throws {
        let fixture = try makeStoredSession()
        let store = ResearchFaceGeometryStore()
        let session = try store.loadSession(at: fixture.directory.url)
        let wrong = ResearchFaceGeometryConfiguration.empty(topologyID: "different")
        let url = fixture.directory.url.appendingPathComponent("wrong.json")
        try store.encoded(wrong).write(to: url)
        XCTAssertThrowsError(try store.importDraft(from: url, for: session))
    }

    func testHistoricalOrMissingMeshSessionFailsWithoutCreatingDraft() throws {
        let directory = try TemporaryDirectory(testName: #function)
        try JSONExporter().export(TestFixtures.metadata(), to: directory.url.appendingPathComponent("metadata.json"))
        let store = ResearchFaceGeometryStore()
        XCTAssertThrowsError(try store.loadSession(at: directory.url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.url.appendingPathComponent(ResearchFaceGeometryStore.draftFileName).path))
    }

    func testDraftDoesNotMutateSessionMetadata() throws {
        let fixture = try makeStoredSession()
        let store = ResearchFaceGeometryStore()
        let metadataURL = fixture.directory.url.appendingPathComponent("metadata.json")
        let before = try Data(contentsOf: metadataURL)
        let session = try store.loadSession(at: fixture.directory.url)
        _ = try store.exportDraft(.empty(topologyID: session.topology.topologyID), for: session)
        XCTAssertEqual(try Data(contentsOf: metadataURL), before)
    }

    func testCandidateRoundTripAndDerivedExportDoNotRewriteSourceMetadata() throws {
        let fixture = try makeStoredSession()
        let store = ResearchFaceGeometryStore()
        let session = try store.loadSession(at: fixture.directory.url)
        let metadataURL = fixture.directory.url.appendingPathComponent("metadata.json")
        let rawURL = fixture.directory.url.appendingPathComponent(SessionStore.rawFaceMeshFramesFileName)
        let metadataBefore = try Data(contentsOf: metadataURL)
        let rawBefore = try Data(contentsOf: rawURL)
        let draft = ResearchFaceGeometryConfiguration.empty(topologyID: session.topology.topologyID)
        let candidate = CandidateFaceGeometryConfiguration.freeze(
            draft: draft, configurationID: "candidate", createdAt: Date(timeIntervalSince1970: 1),
            bilateralLandmarkPairs: [], bilateralRegionPairs: []
        )
        let url = try store.exportCandidate(candidate, for: session)
        XCTAssertEqual(try store.importCandidate(from: url, for: session), candidate)
        XCTAssertEqual(try Data(contentsOf: metadataURL), metadataBefore)
        XCTAssertEqual(try Data(contentsOf: rawURL), rawBefore)
        XCTAssertEqual(session.metadata.analysisAlgorithmVersion, "0.3.0")
    }

    private func makeStoredSession() throws -> (directory: TemporaryDirectory, topology: FaceMeshTopology) {
        let directory = try TemporaryDirectory(testName: UUID().uuidString)
        let topology = FaceMeshTopology(vertexCount: 4, triangleCount: 2, triangleIndices: [0, 1, 2, 0, 2, 3],
            textureCoordinates: [.init(u: 0, v: 0), .init(u: 1, v: 0), .init(u: 1, v: 1), .init(u: 0, v: 1)])
        let frame = RawFaceMeshFrame(id: UUID(), rawFrameID: UUID(), recordingID: UUID(), sourceTimestamp: 1,
            taskType: .neutralRest, repetitionIndex: 1, frameIndex: 0, topologyID: topology.topologyID,
            vertices: [.init(x: 0, y: 0, z: 0), .init(x: 1, y: 0, z: 0), .init(x: 2, y: 0, z: 0), .init(x: 0, y: 1, z: 0)])
        try JSONExporter().export(activeMetadata(), to: directory.url.appendingPathComponent("metadata.json"))
        try JSONExporter().export(topology, to: directory.url.appendingPathComponent(SessionStore.faceMeshTopologyFileName))
        try JSONExporter().export(RawFaceMeshFramesExport(frames: [frame], unavailableFrames: []),
                                  to: directory.url.appendingPathComponent(SessionStore.rawFaceMeshFramesFileName))
        return (directory, topology)
    }

    private func activeMetadata() -> SessionMetadata {
        let base = TestFixtures.metadata()
        return SessionMetadata(sessionID: base.sessionID, studyID: base.studyID, participantID: base.participantID, raterID: base.raterID,
            appVersion: base.appVersion, deviceModel: base.deviceModel, osVersion: base.osVersion, sessionDate: base.sessionDate,
            notes: base.notes, affectedSide: base.affectedSide, sessionLabel: base.sessionLabel,
            appMarketingVersion: base.appMarketingVersion, appBuildNumber: base.appBuildNumber,
            rawDataSchemaVersion: "4.0.0", analysisAlgorithmVersion: "0.3.0", captureProtocolVersion: "0.4.0",
            meshCaptureVersion: "1.0.0", landmarkConfigurationVersion: "not-active",
            deviceModelIdentifier: base.deviceModelIdentifier, operatingSystemName: base.operatingSystemName,
            operatingSystemVersion: base.operatingSystemVersion)
    }
}
