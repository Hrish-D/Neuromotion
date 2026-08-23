import XCTest
@testable import Facework

final class FaceGeometryMeasurementEngineTests: XCTestCase {
    func testDraftFreezesToIndependentResearchCandidateWithDeterministicHash() {
        let draft = makeDraft()
        let original = draft
        let first = freeze(draft)
        let second = CandidateFaceGeometryConfiguration.freeze(
            draft: draft, configurationID: "different", configurationVersion: "candidate-1",
            createdAt: Date(timeIntervalSince1970: 999), bilateralLandmarkPairs: landmarkPairs(),
            bilateralRegionPairs: regionPairs(), scaleReferenceLineID: "scale"
        )
        XCTAssertNotEqual(first.configurationID, draft.configurationID)
        XCTAssertEqual(first.status, .candidateForReview)
        XCTAssertTrue(first.researchUseOnly)
        XCTAssertFalse(first.clinicallyValidated)
        XCTAssertEqual(first.requiredTopologyID, draft.requiredTopologyID)
        XCTAssertEqual(first.configurationHash, second.configurationHash)
        XCTAssertEqual(draft, original)

        var changedLandmark = draft
        changedLandmark.landmarks[0] = .init(id: "left", displayName: "Test Left A", source: .meshVertex(index: 2), side: .subjectLeft)
        XCTAssertNotEqual(freeze(changedLandmark).configurationHash, first.configurationHash)
        var changedRegion = draft
        changedRegion.regions[0] = .init(id: "leftRegion", displayName: "Test Left Region", vertexIndices: [0], side: .subjectLeft)
        XCTAssertNotEqual(freeze(changedRegion).configurationHash, first.configurationHash)
        let changedPairs = [BilateralLandmarkPair(id: "pair", displayName: "Changed", subjectLeftLandmarkID: "right", subjectRightLandmarkID: "left", notes: nil)]
        XCTAssertNotEqual(CandidateFaceGeometryConfiguration.freeze(draft: draft, bilateralLandmarkPairs: changedPairs, bilateralRegionPairs: regionPairs()).configurationHash, first.configurationHash)
    }

    func testCandidateMeasurementNamesResolveHumanReadableEntities() {
        let names = CandidateMeasurementNames(candidate: freeze(makeDraft()))
        XCTAssertEqual(names.landmark("left"), "Test Left A")
        XCTAssertEqual(names.region("leftRegion"), "Test Left Region")
        XCTAssertEqual(names.landmarkPair("landmarkPair")?.displayName, "Test Bilateral Pair")
        XCTAssertEqual(names.regionPair("regionPair")?.displayName, "Test Bilateral Regions")
        XCTAssertEqual(names.region("unknown"), "unknown")
    }

    func testCandidatePairValidationRequiresDistinctExistingCorrectSides() {
        let fixture = makeFixture()
        XCTAssertEqual(CandidateConfigurationValidator.validate(freeze(makeDraft()), topology: fixture.session.topology, frame: fixture.neutral[0]), [])
        let same = [BilateralLandmarkPair(id: "bad", displayName: "Bad", subjectLeftLandmarkID: "left", subjectRightLandmarkID: "left", notes: nil)]
        XCTAssertTrue(issues(landmarkPairs: same).contains(.sameLandmark(pairID: "bad")))
        let missing = [BilateralLandmarkPair(id: "bad", displayName: "Bad", subjectLeftLandmarkID: "missing", subjectRightLandmarkID: "right", notes: nil)]
        XCTAssertTrue(issues(landmarkPairs: missing).contains(.missingLandmark(pairID: "bad", landmarkID: "missing")))
        var wrongDraft = makeDraft()
        wrongDraft.landmarks[0] = .init(id: "left", displayName: "Left", source: .meshVertex(index: 0), side: .unspecified)
        XCTAssertTrue(CandidateConfigurationValidator.validate(freeze(wrongDraft), topology: fixture.session.topology, frame: fixture.neutral[0]).contains(.wrongLandmarkSide(pairID: "landmarkPair")))
        let sameRegion = [BilateralRegionPair(id: "bad", displayName: "Bad", subjectLeftRegionID: "leftRegion", subjectRightRegionID: "leftRegion", notes: nil)]
        XCTAssertTrue(issues(regionPairs: sameRegion).contains(.sameRegion(pairID: "bad")))
        let missingRegion = [BilateralRegionPair(id: "bad", displayName: "Bad", subjectLeftRegionID: "missing", subjectRightRegionID: "rightRegion", notes: nil)]
        XCTAssertTrue(issues(regionPairs: missingRegion).contains(.missingRegion(pairID: "bad", regionID: "missing")))
    }

    func testMedianHelpersOddEvenAndOutlier() {
        XCTAssertEqual(FaceGeometryMath.median([3, 1, 2]), 2)
        XCTAssertEqual(FaceGeometryMath.median([4, 1, 3, 2]), 2.5)
        XCTAssertEqual(FaceGeometryMath.median([0.039, 0.04, 2]), 0.04)
        XCTAssertEqual(FaceGeometryMath.componentMedian([.init(x: 1, y: 4, z: 7), .init(x: 2, y: 5, z: 8), .init(x: 100, y: 6, z: 9)]),
                       .init(x: 2, y: 5, z: 8))
    }

    func testNeutralReferenceUsesOnlyExplicitFinalSelectionAndRetainsProvenance() throws {
        let fixture = makeFixture()
        let candidate = freeze(makeDraft())
        let original = fixture.neutral.flatMap(\.vertices)
        let engine = FaceGeometryMeasurementEngine()
        let reference = try XCTUnwrap(engine.buildNeutralReference(session: fixture.session, candidate: candidate,
            selectedMeshFrameIDs: Set(fixture.neutral.map(\.id))))
        XCTAssertEqual(reference.neutralFrameCount, 3)
        XCTAssertEqual(reference.neutralTimeSpanSeconds, 0.23, accuracy: 1e-12)
        XCTAssertEqual(reference.contributingMeshFrameIDs, fixture.neutral.map(\.id))
        XCTAssertEqual(reference.contributingRawFrameIDs, fixture.neutral.map(\.rawFrameID))
        XCTAssertEqual(reference.contributingSourceTimestamps, fixture.neutral.map(\.sourceTimestamp))
        XCTAssertEqual(try XCTUnwrap(reference.baselineByVertexIndex[0]).x, 0.04, accuracy: 1e-6)
        XCTAssertEqual(fixture.neutral.flatMap(\.vertices), original)
        XCTAssertNil(engine.buildNeutralReference(session: fixture.session, candidate: candidate, selectedMeshFrameIDs: []))
        XCTAssertEqual(engine.analyze(session: fixture.session, candidate: candidate, selectedNeutralMeshFrameIDs: []), .failure(.missingNeutralReference))
        let finalOnly = engine.buildNeutralReference(session: fixture.session, candidate: candidate,
                                                     selectedMeshFrameIDs: [fixture.neutral[1].id])
        XCTAssertEqual(finalOnly?.contributingMeshFrameIDs, [fixture.neutral[1].id])
    }

    func testLandmarkDisplacementAxesMillimetresAndSideSemantics() throws {
        let result = try expressionResult()
        let left = try XCTUnwrap(result.landmarks.first { $0.landmarkID == "left" })
        let right = try XCTUnwrap(result.landmarks.first { $0.landmarkID == "right" })
        let leftDelta = try XCTUnwrap(left.delta)
        XCTAssertEqual(leftDelta.x, 0.01, accuracy: 1e-6)
        XCTAssertEqual(leftDelta.y, 0.01, accuracy: 1e-6)
        XCTAssertEqual(leftDelta.z, 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(left.displacementMagnitudeMeters), sqrt(0.0002), accuracy: 1e-6)
        XCTAssertEqual((left.displacementMagnitudeMeters ?? 0) * 1_000, sqrt(200), accuracy: 1e-3)
        XCTAssertEqual(try XCTUnwrap(left.outwardLateralDisplacementMeters), 0.01, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(right.outwardLateralDisplacementMeters), 0.01, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(left.superiorDisplacementMeters), 0.01, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(left.anteriorDisplacementMeters), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(try neutralResult().landmarks.first?.displacementMagnitudeMeters), 0, accuracy: 1e-6)
    }

    func testBilateralLandmarkMirroringAndSafeAsymmetry() throws {
        let pair = try XCTUnwrap(try expressionResult().bilateralLandmarks.first)
        XCTAssertEqual(try XCTUnwrap(pair.leftMagnitudeMeters), try XCTUnwrap(pair.rightMagnitudeMeters), accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(pair.magnitudeDifferenceMeters), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(pair.vectorMismatchMeters), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(pair.asymmetryIndex), 0, accuracy: 1e-6)
        XCTAssertNil(FaceGeometryMath.asymmetryIndex(0, 0))
        XCTAssertEqual(FaceGeometryMath.asymmetryIndex(1, 3), 0.5)
        let mirrored = FaceGeometryMath.mirrorAcrossYZ(.init(x: -1, y: 2, z: 3))
        XCTAssertEqual(mirrored, .init(x: 1, y: 2, z: 3))
        XCTAssertTrue([pair.leftMagnitudeMeters, pair.rightMagnitudeMeters, pair.vectorMismatchMeters].compactMap { $0 }.allSatisfy(\.isFinite))
    }

    func testLineAndPolylineLengthsChangesScaleAndOrder() throws {
        let result = try expressionResult()
        let line = try XCTUnwrap(result.lines.first)
        XCTAssertEqual(try XCTUnwrap(line.neutralLengthMeters), 0.08, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(line.currentLengthMeters), 0.10, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(line.lengthChangeMeters), 0.02, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(line.percentChange), 0.25, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(line.normalizedCurrentLength), 1.25, accuracy: 1e-6)
        let path = try XCTUnwrap(result.polylines.first)
        XCTAssertGreaterThan(try XCTUnwrap(path.currentLengthMeters), try XCTUnwrap(line.currentLengthMeters))
        XCTAssertNotEqual(FaceGeometryMath.pathLength([.init(x: 0, y: 0, z: 0), .init(x: 1, y: 1, z: 0), .init(x: 2, y: 0, z: 0)]),
                          FaceGeometryMath.pathLength([.init(x: 0, y: 0, z: 0), .init(x: 2, y: 0, z: 0), .init(x: 1, y: 1, z: 0)]))
        XCTAssertNil(FaceGeometryMath.asymmetryIndex(0, 0))
    }

    func testRegionCentroidRMSMeanMaxAndCancellationDistinction() throws {
        let result = try expressionResult()
        let region = try XCTUnwrap(result.regions.first { $0.regionID == "leftRegion" })
        XCTAssertNotNil(region.centroidCurrent)
        XCTAssertNotNil(region.centroidNeutral)
        XCTAssertEqual(try XCTUnwrap(region.centroidDelta).x, 0.005, accuracy: 1e-6)
        XCTAssertGreaterThan(try XCTUnwrap(region.rmsVertexDisplacementMeters), 0)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(region.maximumVertexDisplacementMagnitudeMeters), try XCTUnwrap(region.meanVertexDisplacementMagnitudeMeters))
        let opposing = [GeometryVector3(x: 1, y: 0, z: 0), GeometryVector3(x: -1, y: 0, z: 0)]
        XCTAssertEqual(FaceGeometryMath.centroid(opposing), .zero)
        let rms = sqrt(opposing.map { $0.magnitude * $0.magnitude }.reduce(0, +) / 2)
        XCTAssertEqual(rms, 1)
        XCTAssertEqual(FaceGeometryMath.centroid([.init(x: 1, y: 2, z: 3)]), .init(x: 1, y: 2, z: 3))
    }

    func testBilateralRegionsCompareAggregatesWithoutVertexCorrespondence() throws {
        let pair = try XCTUnwrap(try expressionResult().bilateralRegions.first)
        XCTAssertEqual(try XCTUnwrap(pair.absoluteCentroidDifferenceMeters), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(pair.centroidVectorMismatchMeters), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(pair.absoluteRMSDifferenceMeters), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(pair.centroidAsymmetryIndex), 0, accuracy: 1e-6)
        XCTAssertNil(FaceGeometryMath.asymmetryIndex(0, 0))
    }

    func testPlaneNormalAreaDegeneracyAndOrientation() throws {
        let neutral = try XCTUnwrap(try neutralResult().planes.first)
        XCTAssertEqual(try XCTUnwrap(neutral.orientationChangeDegrees), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(neutral.neutralTriangleAreaSquareMeters), 0.0008, accuracy: 1e-6)
        let a = GeometryVector3(x: 0, y: 0, z: 0), b = GeometryVector3(x: 1, y: 0, z: 0), c = GeometryVector3(x: 0, y: 1, z: 0)
        XCTAssertEqual(FaceGeometryMath.normalized(FaceGeometryMath.cross(b - a, c - a)), .init(x: 0, y: 0, z: 1))
        XCTAssertNil(FaceGeometryMath.normalized(FaceGeometryMath.cross(b - a, .init(x: 2, y: 0, z: 0) - a)))
        XCTAssertEqual(acos(min(1, max(-1, abs(-1.0000000001)))) * 180 / .pi, 0)
        let ninety = acos(abs(FaceGeometryMath.dot(.init(x: 0, y: 0, z: 1), .init(x: 0, y: 1, z: 0)))) * 180 / .pi
        XCTAssertEqual(ninety, 90)
    }

    func testExactTimeSummariesAndCompleteProvenance() throws {
        let fixture = makeFixture()
        let package = try FaceGeometryMeasurementEngine().analyze(session: fixture.session, candidate: freeze(makeDraft()),
                                                                   selectedNeutralMeshFrameIDs: Set(fixture.neutral.map(\.id))).get()
        let frame = try XCTUnwrap(package.frames.first { $0.rawFaceMeshFrameID == fixture.expression.id })
        XCTAssertEqual(frame.rawFrameID, fixture.expression.rawFrameID)
        XCTAssertEqual(frame.rawFaceMeshFrameID, fixture.expression.id)
        XCTAssertEqual(frame.recordingID, fixture.expression.recordingID)
        XCTAssertEqual(frame.sourceTimestamp, 11.37)
        XCTAssertEqual(frame.topologyID, fixture.session.topology.topologyID)
        XCTAssertEqual(frame.candidateConfigurationID, package.candidateConfigurationID)
        XCTAssertEqual(frame.candidateConfigurationHash, package.candidateConfigurationHash)
        XCTAssertEqual(frame.measurementAnalysisAlgorithmVersion, "0.4.0")
        XCTAssertEqual(frame.measurementSchemaVersion, "1.0.0")
        XCTAssertEqual(frame.neutralReferenceID, package.neutralReference.neutralReferenceID)
        let summary = try XCTUnwrap(package.repetitionSummaries.first { $0.taskType == .smileClosed && $0.measurementID == "landmark:left:magnitude" })
        XCTAssertEqual(summary.firstTimestamp, 11.37)
        XCTAssertEqual(summary.lastTimestamp, 11.37)
        XCTAssertEqual(summary.durationSeconds, 0)
        XCTAssertEqual(summary.peakTimestamp, 11.37)
        XCTAssertEqual(summary.timeToPeakSeconds, 0)
    }

    func testPhysicalStyleCandidateProducesCompletePrimarySummaryCoverage() throws {
        let baseFixture = makeFixture()
        var draft = makeDraft()
        draft.landmarks = Array(draft.landmarks.prefix(2))
        draft.lines = []; draft.polylines = []; draft.planes = []
        let candidate = CandidateFaceGeometryConfiguration.freeze(
            draft: draft, configurationID: "physical-style", configurationVersion: "candidate-1",
            createdAt: Date(timeIntervalSince1970: 100), bilateralLandmarkPairs: landmarkPairs(),
            bilateralRegionPairs: regionPairs()
        )
        let recordingID = baseFixture.expression.recordingID
        let topology = baseFixture.session.topology
        let tasks: [(TaskType, Int)] = [(.neutralRest, 1)] + TaskType.allCases.filter { $0 != .neutralRest }.flatMap { task in
            (1...3).map { (task, $0) }
        }
        let frames = tasks.enumerated().map { offset, item in
            RawFaceMeshFrame(id: UUID(), rawFrameID: UUID(), recordingID: recordingID,
                             sourceTimestamp: 20 + Double(offset) * 0.117, taskType: item.0,
                             repetitionIndex: item.1, frameIndex: 0, topologyID: topology.topologyID,
                             vertices: baseFixture.expression.vertices)
        }
        let session = StoredFaceMeshSession(
            folderURL: URL(fileURLWithPath: "/tmp/physical-style-summary"), metadata: historicalMetadata(),
            topology: topology, meshExport: .init(frames: frames, unavailableFrames: []),
            rawFrames: frames.map { rawFrame(for: $0, isNeutral: $0.taskType == .neutralRest) }
        )
        let package = try FaceGeometryMeasurementEngine().analyze(
            session: session, candidate: candidate, selectedNeutralMeshFrameIDs: [frames[0].id]
        ).get()
        XCTAssertEqual(package.repetitionSummaries.count, 342)
        XCTAssertEqual(Set(package.repetitionSummaries.map(\.measurementID)).count, 18)
        XCTAssertEqual(package.repetitionSummaries.filter { $0.measurementID.contains(":centroidMagnitude") }.count, 38)
        XCTAssertEqual(package.repetitionSummaries.filter { $0.measurementID.hasPrefix("bilateralRegion:") }.count, 95)
        XCTAssertEqual(package.repetitionSummaries.first?.firstTimestamp,
                       package.repetitionSummaries.first?.lastTimestamp)
        XCTAssertTrue(package.repetitionSummaries.allSatisfy { $0.sampleCount == 1 })
    }

    func testCompleteRegionAndBilateralRegionSummaryIdentitiesAreUnique() throws {
        let fixture = makeFixture()
        let package = try FaceGeometryMeasurementEngine().analyze(
            session: fixture.session, candidate: freeze(makeDraft()),
            selectedNeutralMeshFrameIDs: Set(fixture.neutral.map(\.id))
        ).get()
        let ids = Set(package.repetitionSummaries.map(\.measurementID))
        for regionID in ["leftRegion", "rightRegion"] {
            for metric in ["centroidMagnitude", "rms", "meanMagnitude", "maximumMagnitude"] {
                XCTAssertTrue(ids.contains("region:\(regionID):\(metric)"))
            }
        }
        for metric in ["absoluteCentroidDifference", "centroidVectorMismatch", "centroidAsymmetryIndex",
                       "absoluteRMSDifference", "rmsAsymmetryIndex"] {
            XCTAssertTrue(ids.contains("bilateralRegion:regionPair:\(metric)"))
        }
        XCTAssertEqual(package.repetitionSummaries.map(\.id).count, Set(package.repetitionSummaries.map(\.id)).count)
    }

    func testVersionSeparationDeterminismAndCodableRoundTrip() throws {
        let fixture = makeFixture()
        let candidate = freeze(makeDraft())
        let ids = Set(fixture.neutral.map(\.id))
        let first = try FaceGeometryMeasurementEngine().analyze(session: fixture.session, candidate: candidate, selectedNeutralMeshFrameIDs: ids).get()
        let second = try FaceGeometryMeasurementEngine().analyze(session: fixture.session, candidate: candidate, selectedNeutralMeshFrameIDs: ids).get()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.measurementAnalysisAlgorithmVersion, "0.4.0")
        XCTAssertEqual(first.sourceSessionAnalysisAlgorithmVersion, "0.3.0")
        XCTAssertEqual(ResearchDataVersions.current.rawDataSchemaVersion, "4.0.0")
        XCTAssertEqual(ResearchDataVersions.current.analysisAlgorithmVersion, "0.4.0")
        XCTAssertEqual(ResearchDataVersions.current.captureProtocolVersion, "0.4.0")
        XCTAssertEqual(ResearchDataVersions.current.meshCaptureVersion, "1.0.0")
        XCTAssertEqual(ResearchDataVersions.current.landmarkConfigurationVersion, "not-active")
        let data = try JSONEncoder().encode(first)
        XCTAssertEqual(try JSONDecoder().decode(FaceGeometryMeasurementPackage.self, from: data), first)
        XCTAssertEqual(first.frames.map(\.sourceTimestamp), first.frames.map(\.sourceTimestamp).sorted())
    }

    func testTopologyMismatchAndNonFiniteNeverFabricateValues() throws {
        let fixture = makeFixture()
        var wrongDraft = makeDraft()
        wrongDraft = ResearchFaceGeometryConfiguration(configurationID: wrongDraft.configurationID, configurationName: wrongDraft.configurationName,
            draftRevision: wrongDraft.draftRevision, createdAt: wrongDraft.createdAt, requiredTopologyID: "wrong", status: .draft,
            landmarks: wrongDraft.landmarks, regions: wrongDraft.regions, lines: wrongDraft.lines,
            polylines: wrongDraft.polylines, planes: wrongDraft.planes, notes: wrongDraft.notes)
        XCTAssertEqual(FaceGeometryMeasurementEngine().analyze(session: fixture.session, candidate: freeze(wrongDraft), selectedNeutralMeshFrameIDs: Set(fixture.neutral.map(\.id))), .failure(.topologyMismatch))
        XCTAssertNil(FaceGeometryMath.componentMedian([.init(x: .nan, y: 0, z: 0)]))
        let zeroLength = FaceGeometryMath.pathLength([.zero, .zero])
        XCTAssertEqual(zeroLength, 0)
    }

    func testMissingMeshFrameIsReportedWithoutFabricatedMeasurementValues() throws {
        let fixture = makeFixture()
        let missingRawID = UUID()
        let unavailable = RawFaceMeshUnavailableFrame(
            rawFrameID: missingRawID, recordingID: fixture.expression.recordingID,
            sourceTimestamp: 12.01, taskType: .smileClosed, repetitionIndex: 1, frameIndex: 1,
            reason: .missingGeometry, observedTopologyID: nil
        )
        let session = StoredFaceMeshSession(
            folderURL: fixture.session.folderURL, metadata: fixture.session.metadata,
            topology: fixture.session.topology,
            meshExport: .init(frames: fixture.session.meshExport.frames, unavailableFrames: [unavailable]),
            rawFrames: fixture.session.rawFrames
        )
        let package = try FaceGeometryMeasurementEngine().analyze(
            session: session, candidate: freeze(makeDraft()),
            selectedNeutralMeshFrameIDs: Set(fixture.neutral.map(\.id))
        ).get()
        let result = try XCTUnwrap(package.unavailableMeshFrames.first)
        XCTAssertEqual(result.rawFrameID, missingRawID)
        XCTAssertEqual(result.measurementStatus, .missingMeshFrame)
        XCTAssertEqual(result.sourceMeshAvailability, .missingGeometry)
        XCTAssertFalse(package.frames.contains { $0.rawFrameID == missingRawID })
    }

    func testRepresentative490By1220OfflineWorkloadCompletesSequentially() throws {
        let topology = FaceMeshTopology(
            vertexCount: 1_220, triangleCount: 0, triangleIndices: [],
            textureCoordinates: (0..<1_220).map { .init(u: Float($0) / 1_220, v: 0) }
        )
        var vertices = Array(repeating: FaceMeshVertex(x: 0, y: 0, z: 0), count: topology.vertexCount)
        vertices[0] = .init(x: 0.04, y: 0, z: 0.03)
        vertices[1] = .init(x: -0.04, y: 0, z: 0.03)
        vertices[2] = .init(x: 0.03, y: 0.01, z: 0.02)
        vertices[3] = .init(x: -0.03, y: 0.01, z: 0.02)
        vertices[4] = .init(x: 0, y: 0.02, z: 0.04)
        let recordingID = UUID()
        let neutral = meshFrame(index: 0, timestamp: 1, task: .neutralRest, vertices: vertices,
                                topology: topology, recordingID: recordingID)
        let expressionFrames = (0..<489).map { index in
            meshFrame(index: index, timestamp: 2 + Double(index) * 0.11665, task: .smileClosed,
                      vertices: vertices, topology: topology, recordingID: recordingID)
        }
        let all = [neutral] + expressionFrames
        let session = StoredFaceMeshSession(
            folderURL: URL(fileURLWithPath: "/tmp/synthetic-prompt13-performance"), metadata: historicalMetadata(),
            topology: topology, meshExport: .init(frames: all, unavailableFrames: []),
            rawFrames: all.map { rawFrame(for: $0, isNeutral: $0.taskType == .neutralRest) }
        )
        let source = makeDraft()
        let draft = ResearchFaceGeometryConfiguration(
            configurationID: source.configurationID, configurationName: source.configurationName,
            draftRevision: source.draftRevision, createdAt: source.createdAt, requiredTopologyID: topology.topologyID,
            status: source.status, landmarks: source.landmarks, regions: source.regions, lines: source.lines,
            polylines: source.polylines, planes: source.planes, notes: source.notes
        )
        let candidate = freeze(draft)
        let start = CFAbsoluteTimeGetCurrent()
        let package = try FaceGeometryMeasurementEngine().analyze(
            session: session, candidate: candidate, selectedNeutralMeshFrameIDs: [neutral.id]
        ).get()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertEqual(package.frames.count, 490)
        XCTAssertLessThan(elapsed, 5)
        XCTContext.runActivity(named: String(format: "490 frames × 1220 vertices: %.6f seconds", elapsed)) { _ in }
    }

    private func expressionResult() throws -> FaceGeometryFrameMeasurements {
        let fixture = makeFixture()
        let package = try FaceGeometryMeasurementEngine().analyze(session: fixture.session, candidate: freeze(makeDraft()),
            selectedNeutralMeshFrameIDs: Set(fixture.neutral.map(\.id))).get()
        return try XCTUnwrap(package.frames.first { $0.rawFaceMeshFrameID == fixture.expression.id })
    }
    private func neutralResult() throws -> FaceGeometryFrameMeasurements {
        let fixture = makeFixture()
        let package = try FaceGeometryMeasurementEngine().analyze(session: fixture.session, candidate: freeze(makeDraft()),
            selectedNeutralMeshFrameIDs: Set(fixture.neutral.map(\.id))).get()
        return try XCTUnwrap(package.frames.first { $0.rawFaceMeshFrameID == fixture.neutral[1].id })
    }

    private func issues(landmarkPairs: [BilateralLandmarkPair]? = nil, regionPairs: [BilateralRegionPair]? = nil) -> [CandidateConfigurationIssue] {
        let fixture = makeFixture()
        let candidate = CandidateFaceGeometryConfiguration.freeze(draft: makeDraft(), bilateralLandmarkPairs: landmarkPairs ?? self.landmarkPairs(), bilateralRegionPairs: regionPairs ?? self.regionPairs(), scaleReferenceLineID: "scale")
        return CandidateConfigurationValidator.validate(candidate, topology: fixture.session.topology, frame: fixture.neutral[0])
    }
    private func freeze(_ draft: ResearchFaceGeometryConfiguration) -> CandidateFaceGeometryConfiguration {
        CandidateFaceGeometryConfiguration.freeze(draft: draft, configurationID: "candidate", configurationVersion: "candidate-1",
            createdAt: Date(timeIntervalSince1970: 100), bilateralLandmarkPairs: landmarkPairs(), bilateralRegionPairs: regionPairs(), scaleReferenceLineID: "scale")
    }
    private func landmarkPairs() -> [BilateralLandmarkPair] {
        [.init(id: "landmarkPair", displayName: "Test Bilateral Pair", subjectLeftLandmarkID: "left", subjectRightLandmarkID: "right", notes: nil)]
    }
    private func regionPairs() -> [BilateralRegionPair] {
        [.init(id: "regionPair", displayName: "Test Bilateral Regions", subjectLeftRegionID: "leftRegion", subjectRightRegionID: "rightRegion", notes: nil)]
    }
    private func makeDraft() -> ResearchFaceGeometryConfiguration {
        let topology = makeTopology()
        return .init(configurationID: "draft", configurationName: "Synthetic Candidate", draftRevision: "draft-1",
            createdAt: Date(timeIntervalSince1970: 1), requiredTopologyID: topology.topologyID, status: .draft,
            landmarks: [.init(id: "left", displayName: "Test Left A", source: .meshVertex(index: 0), side: .subjectLeft),
                        .init(id: "right", displayName: "Test Right A", source: .meshVertex(index: 1), side: .subjectRight),
                        .init(id: "plane", displayName: "Test Point C", source: .meshVertex(index: 4), side: .midline)],
            regions: [.init(id: "leftRegion", displayName: "Test Left Region", vertexIndices: [0, 2], side: .subjectLeft),
                      .init(id: "rightRegion", displayName: "Test Right Region", vertexIndices: [1, 3], side: .subjectRight)],
            lines: [.init(id: "scale", displayName: "Test Scale", endpointA: .landmark(id: "left"), endpointB: .landmark(id: "right"))],
            polylines: [.init(id: "path", displayName: "Test Path", points: [.landmark(id: "left"), .landmark(id: "plane"), .landmark(id: "right")])],
            planes: [.init(id: "testPlane", displayName: "Test Plane", pointA: .landmark(id: "left"), pointB: .landmark(id: "right"), pointC: .landmark(id: "plane"))], notes: "Research only")
    }

    private func makeFixture() -> (session: StoredFaceMeshSession, neutral: [RawFaceMeshFrame], expression: RawFaceMeshFrame) {
        let topology = makeTopology(), recordingID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let base = baseVertices()
        let arrays: [[FaceMeshVertex]] = [offset(base, -0.001), base, offset(base, 0.1)]
        let timestamps = [10.0, 10.11, 10.23]
        let neutral = zip(arrays, timestamps).enumerated().map { offset, pair in
            meshFrame(index: offset, timestamp: pair.1, task: .neutralRest, vertices: pair.0, topology: topology, recordingID: recordingID)
        }
        var current = base
        current[0] = .init(x: 0.05, y: 0.01, z: 0.03)
        current[1] = .init(x: -0.05, y: 0.01, z: 0.03)
        current[2] = .init(x: 0.03, y: 0.01, z: 0.02)
        current[3] = .init(x: -0.03, y: 0.01, z: 0.02)
        current[4] = .init(x: 0, y: 0.02, z: 0.04)
        let expression = meshFrame(index: 0, timestamp: 11.37, task: .smileClosed, vertices: current, topology: topology, recordingID: recordingID)
        let all = neutral + [expression]
        let raws = all.map { rawFrame(for: $0, isNeutral: $0.taskType == .neutralRest) }
        let metadata = historicalMetadata()
        return (.init(folderURL: URL(fileURLWithPath: "/tmp/synthetic-prompt13"), metadata: metadata,
                      topology: topology, meshExport: .init(frames: all, unavailableFrames: []), rawFrames: raws), neutral, expression)
    }
    private func makeTopology() -> FaceMeshTopology {
        .init(vertexCount: 6, triangleCount: 4, triangleIndices: [0, 2, 4, 0, 4, 1, 1, 4, 3, 2, 3, 5],
              textureCoordinates: (0..<6).map { .init(u: Float($0) / 5, v: 0) })
    }
    private func baseVertices() -> [FaceMeshVertex] {
        [.init(x: 0.04, y: 0, z: 0.03), .init(x: -0.04, y: 0, z: 0.03),
         .init(x: 0.03, y: 0.01, z: 0.02), .init(x: -0.03, y: 0.01, z: 0.02),
         .init(x: 0, y: 0.02, z: 0.03), .init(x: 0, y: -0.02, z: 0.03)]
    }
    private func offset(_ vertices: [FaceMeshVertex], _ amount: Float) -> [FaceMeshVertex] {
        vertices.map { .init(x: $0.x + amount, y: $0.y + amount, z: $0.z + amount) }
    }
    private func meshFrame(index: Int, timestamp: Double, task: TaskType, vertices: [FaceMeshVertex], topology: FaceMeshTopology, recordingID: UUID) -> RawFaceMeshFrame {
        .init(id: UUID(), rawFrameID: UUID(), recordingID: recordingID, sourceTimestamp: timestamp,
              taskType: task, repetitionIndex: 1, frameIndex: index, topologyID: topology.topologyID, vertices: vertices)
    }
    private func rawFrame(for mesh: RawFaceMeshFrame, isNeutral: Bool) -> RawFrameCapture {
        .init(id: mesh.rawFrameID, recordingID: mesh.recordingID, frameIndex: mesh.frameIndex, sourceTimestamp: mesh.sourceTimestamp,
              taskType: mesh.taskType, repetitionIndex: mesh.repetitionIndex, rawBlendshapes: [:], faceTransform: nil, headPose: nil,
              faceIsPresent: true, visibleFaceCount: 1, faceTrackingState: .tracking, faceCenter: nil, faceScale: nil,
              cameraTrackingStateAtCapture: "Tracking", isNeutralPhase: isNeutral, validationImageReference: nil)
    }
    private func historicalMetadata() -> SessionMetadata {
        let base = TestFixtures.metadata()
        return .init(sessionID: "prompt11-session", studyID: base.studyID, participantID: base.participantID, raterID: base.raterID,
            appVersion: base.appVersion, deviceModel: base.deviceModel, osVersion: base.osVersion, sessionDate: base.sessionDate,
            notes: base.notes, affectedSide: base.affectedSide, sessionLabel: base.sessionLabel,
            appMarketingVersion: base.appMarketingVersion, appBuildNumber: base.appBuildNumber,
            rawDataSchemaVersion: "4.0.0", analysisAlgorithmVersion: "0.3.0", captureProtocolVersion: "0.4.0",
            meshCaptureVersion: "1.0.0", landmarkConfigurationVersion: "not-active",
            deviceModelIdentifier: base.deviceModelIdentifier, operatingSystemName: base.operatingSystemName,
            operatingSystemVersion: base.operatingSystemVersion)
    }
}
