import XCTest
@testable import Facework

@MainActor
final class FaceMeshInspectorPrompt13WorkflowTests: XCTestCase {
    func testProductionPrompt13ControlContractIncludesEveryReachableSection() {
        XCTAssertEqual(Set(Prompt13AnalysisControl.allCases), [
            .configuration, .bilateralLandmarkPairs, .bilateralRegionPairs, .scaleReference,
            .candidateConfiguration, .neutralReference, .analysis, .exports
        ])
        XCTAssertEqual(Prompt13AnalysisControl.bilateralLandmarkPairs.rawValue, "bilateralLandmarkPairsSection")
        XCTAssertEqual(Prompt13AnalysisControl.exports.rawValue, "prompt13ExportsSection")
    }

    func testPhysicalTwoLandmarkScenarioCreatesExactlyOneVisibleWorkspacePair() throws {
        let fixture = makeFixture()
        let source = draft(topologyID: fixture.topology.topologyID)
        let left = try XCTUnwrap(source.landmarks.first { $0.side == .subjectLeft })
        let right = try XCTUnwrap(source.landmarks.first { $0.side == .subjectRight })
        XCTAssertEqual(left.displayName, "Test Left A")
        XCTAssertEqual(right.displayName, "Test Right A")
        let pair = BilateralLandmarkPair(id: "pair", displayName: "Test Bilateral Pair A",
                                         subjectLeftLandmarkID: left.id, subjectRightLandmarkID: right.id, notes: nil)
        let pairs = try Prompt13PairWorkspace.addingLandmarkPair(
            pair, to: [], regionPairs: [], draft: source, topology: fixture.topology, frame: fixture.frame
        ).get()
        XCTAssertEqual(pairs, [pair])
    }

    func testRegionPairWorkspaceIsAvailableBeforeCandidateFreeze() throws {
        let fixture = makeFixture()
        let source = draft(topologyID: fixture.topology.topologyID)
        let left = try XCTUnwrap(source.regions.first { $0.side == .subjectLeft })
        let right = try XCTUnwrap(source.regions.first { $0.side == .subjectRight })
        let pair = BilateralRegionPair(id: "region-pair", displayName: "Test Bilateral Regions",
                                       subjectLeftRegionID: left.id, subjectRightRegionID: right.id, notes: nil)
        let pairs = try Prompt13PairWorkspace.addingRegionPair(
            pair, to: [], landmarkPairs: [], draft: source, topology: fixture.topology, frame: fixture.frame
        ).get()
        XCTAssertEqual(pairs, [pair])
    }

    func testDraftRegionSidesAreExplicitAndRoundTripWithoutCoordinateInference() throws {
        let regions = [
            FaceRegionDefinition(id: "left", displayName: "Test Left Region", vertexIndices: [0, 2], side: .subjectLeft),
            FaceRegionDefinition(id: "right", displayName: "Test Right Region", vertexIndices: [1, 3], side: .subjectRight),
            FaceRegionDefinition(id: "unspecified", displayName: "Historical Region", vertexIndices: [0])
        ]
        let decoded = try JSONDecoder().decode([FaceRegionDefinition].self, from: JSONEncoder().encode(regions))
        XCTAssertEqual(decoded.map(\.side), [.subjectLeft, .subjectRight, .unspecified])

        // Coordinate signs are deliberately opposite the labels; side remains researcher-assigned metadata.
        let positiveXRight = FaceRegionDefinition(id: "positive", displayName: "Manual Right", vertexIndices: [0], side: .subjectRight)
        XCTAssertEqual(positiveXRight.side, .subjectRight)
    }

    func testHistoricalRegionWithoutSideDecodesAsUnspecified() throws {
        let json = Data(#"{"id":"legacy","displayName":"Legacy Region","vertexIndices":[0,1],"notes":null}"#.utf8)
        let region = try JSONDecoder().decode(FaceRegionDefinition.self, from: json)
        XCTAssertEqual(region.side, .unspecified)
    }

    func testRegionPairRejectsReversedAndDuplicateSides() throws {
        let fixture = makeFixture()
        let source = draft(topologyID: fixture.topology.topologyID)
        let reversed = BilateralRegionPair(id: "reversed", displayName: "Reversed",
                                            subjectLeftRegionID: "right-region", subjectRightRegionID: "left-region", notes: nil)
        XCTAssertThrowsError(try Prompt13PairWorkspace.addingRegionPair(
            reversed, to: [], landmarkPairs: [], draft: source, topology: fixture.topology, frame: fixture.frame
        ).get())
        let same = BilateralRegionPair(id: "same", displayName: "Same",
                                        subjectLeftRegionID: "left-region", subjectRightRegionID: "left-region", notes: nil)
        XCTAssertThrowsError(try Prompt13PairWorkspace.addingRegionPair(
            same, to: [], landmarkPairs: [], draft: source, topology: fixture.topology, frame: fixture.frame
        ).get())
    }

    func testCandidatePreservesRegionSideAndHashChangesWithSide() {
        let original = draft(topologyID: "topology")
        var changed = original
        let region = changed.regions[0]
        changed.regions[0] = FaceRegionDefinition(id: region.id, displayName: region.displayName,
                                                  vertexIndices: region.vertexIndices, side: .unspecified)
        let first = CandidateFaceGeometryConfiguration.freeze(
            draft: original, configurationID: "candidate-a", createdAt: Date(timeIntervalSince1970: 2),
            bilateralLandmarkPairs: [], bilateralRegionPairs: []
        )
        let second = CandidateFaceGeometryConfiguration.freeze(
            draft: changed, configurationID: "candidate-b", createdAt: Date(timeIntervalSince1970: 2),
            bilateralLandmarkPairs: [], bilateralRegionPairs: []
        )
        XCTAssertEqual(first.regions[0].side, .subjectLeft)
        XCTAssertNotEqual(first.configurationHash, second.configurationHash)
    }

    private func draft(topologyID: String) -> ResearchFaceGeometryConfiguration {
        .init(
            configurationID: "physical-draft", configurationName: "Physical Regression",
            draftRevision: "draft-1", createdAt: Date(timeIntervalSince1970: 1),
            requiredTopologyID: topologyID, status: .draft,
            landmarks: [
                .init(id: "left", displayName: "Test Left A", source: .meshVertex(index: 0), side: .subjectLeft),
                .init(id: "right", displayName: "Test Right A", source: .meshVertex(index: 1), side: .subjectRight)
            ],
            regions: [
                .init(id: "left-region", displayName: "Test Left Region", vertexIndices: [0, 2], side: .subjectLeft),
                .init(id: "right-region", displayName: "Test Right Region", vertexIndices: [1, 3], side: .subjectRight)
            ], lines: [], polylines: [], planes: [], notes: nil
        )
    }

    private func makeFixture() -> (session: StoredFaceMeshSession, topology: FaceMeshTopology, frame: RawFaceMeshFrame) {
        let topology = FaceMeshTopology(
            vertexCount: 4, triangleCount: 2, triangleIndices: [0, 1, 2, 1, 3, 2],
            textureCoordinates: [.init(u: 0, v: 0), .init(u: 1, v: 0), .init(u: 0, v: 1), .init(u: 1, v: 1)]
        )
        let rawID = UUID(), recordingID = UUID()
        let frame = RawFaceMeshFrame(
            id: UUID(), rawFrameID: rawID, recordingID: recordingID, sourceTimestamp: 10,
            taskType: .neutralRest, repetitionIndex: 1, frameIndex: 0, topologyID: topology.topologyID,
            vertices: [.init(x: 0.04, y: 0, z: 0.03), .init(x: -0.04, y: 0, z: 0.03),
                       .init(x: 0.03, y: 0.01, z: 0.02), .init(x: -0.03, y: 0.01, z: 0.02)]
        )
        let raw = RawFrameCapture(
            id: rawID, recordingID: recordingID, frameIndex: 0, sourceTimestamp: 10,
            taskType: .neutralRest, repetitionIndex: 1, rawBlendshapes: [:], faceTransform: nil,
            headPose: nil, faceIsPresent: true, visibleFaceCount: 1, faceTrackingState: .tracking,
            faceCenter: nil, faceScale: nil, cameraTrackingStateAtCapture: "Tracking",
            isNeutralPhase: true, validationImageReference: nil
        )
        let base = TestFixtures.metadata()
        let metadata = SessionMetadata(
            sessionID: base.sessionID, studyID: base.studyID, participantID: base.participantID,
            raterID: base.raterID, appVersion: base.appVersion, deviceModel: base.deviceModel,
            osVersion: base.osVersion, sessionDate: base.sessionDate, notes: base.notes,
            affectedSide: base.affectedSide, sessionLabel: base.sessionLabel,
            appMarketingVersion: base.appMarketingVersion, appBuildNumber: base.appBuildNumber,
            rawDataSchemaVersion: "4.0.0", analysisAlgorithmVersion: "0.3.0",
            captureProtocolVersion: "0.4.0", meshCaptureVersion: "1.0.0",
            landmarkConfigurationVersion: "not-active", deviceModelIdentifier: base.deviceModelIdentifier,
            operatingSystemName: base.operatingSystemName, operatingSystemVersion: base.operatingSystemVersion
        )
        let session = StoredFaceMeshSession(
            folderURL: FileManager.default.temporaryDirectory.appendingPathComponent("prompt13-ui-\(UUID().uuidString)"), metadata: metadata,
            topology: topology, meshExport: .init(frames: [frame], unavailableFrames: []), rawFrames: [raw]
        )
        return (session, topology, frame)
    }
}
