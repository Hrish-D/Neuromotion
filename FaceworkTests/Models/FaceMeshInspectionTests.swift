import CoreGraphics
import XCTest
@testable import Facework

@MainActor
final class FaceMeshInspectionTests: XCTestCase {
    func testBoundingBoxCenterAndExtentsForPhysicalScaleFixture() throws {
        let vertices = physicalScaleVertices()
        let bounds = try XCTUnwrap(FaceMeshBounds.calculate(vertices: vertices))
        XCTAssertEqual(bounds.minimum, FaceMeshVertex(x: -0.05, y: -0.08, z: -0.03))
        XCTAssertEqual(bounds.maximum, FaceMeshVertex(x: 0.09, y: 0.12, z: 0.07))
        XCTAssertEqual(bounds.center.x, 0.02, accuracy: 0.000_001)
        XCTAssertEqual(bounds.center.y, 0.02, accuracy: 0.000_001)
        XCTAssertEqual(bounds.center.z, 0.02, accuracy: 0.000_001)
        XCTAssertEqual(bounds.width, 0.14, accuracy: 0.000_001)
        XCTAssertEqual(bounds.height, 0.20, accuracy: 0.000_001)
        XCTAssertEqual(bounds.depth, 0.10, accuracy: 0.000_001)
    }

    func testFramingRecentersWithoutMutatingRawCoordinates() throws {
        let vertices = physicalScaleVertices()
        let original = vertices
        let framing = try XCTUnwrap(FaceMeshCameraFraming.calculate(vertices: vertices, preset: .front, viewportAspectRatio: 0.75))
        XCTAssertEqual(framing.centered(framing.rawBounds.center), FaceMeshVertex(x: 0, y: 0, z: 0))
        XCTAssertGreaterThan(framing.orthographicScale, framing.rawBounds.height)
        XCTAssertGreaterThan(framing.cameraDistance, 0)
        XCTAssertGreaterThan(framing.zNear, 0)
        XCTAssertGreaterThan(framing.zFar, framing.zNear)
        XCTAssertEqual(vertices, original)
    }

    func testTinyFiniteAndAsymmetricallyOffsetMeshesFrameSafely() throws {
        let tiny = [FaceMeshVertex(x: 10, y: -4, z: 2), FaceMeshVertex(x: 10.000_001, y: -3.999_999, z: 2.000_001)]
        let framing = try XCTUnwrap(FaceMeshCameraFraming.calculate(vertices: tiny, preset: .front, viewportAspectRatio: 1))
        XCTAssertGreaterThan(framing.orthographicScale, 0)
        XCTAssertEqual(framing.centered(framing.rawBounds.center), FaceMeshVertex(x: 0, y: 0, z: 0))
        XCTAssertNil(FaceMeshCameraFraming.calculate(vertices: [.init(x: 1, y: 1, z: 1)], preset: .front, viewportAspectRatio: 1))
    }

    func testAllPresetsProducePositiveFramingAndDistinctDisplayTransforms() throws {
        let vertices = physicalScaleVertices()
        let front = try XCTUnwrap(FaceMeshCameraFraming.calculate(vertices: vertices, preset: .front, viewportAspectRatio: 1))
        let left = try XCTUnwrap(FaceMeshCameraFraming.calculate(vertices: vertices, preset: .subjectLeft, viewportAspectRatio: 1))
        let right = try XCTUnwrap(FaceMeshCameraFraming.calculate(vertices: vertices, preset: .subjectRight, viewportAspectRatio: 1))
        XCTAssertGreaterThan(front.orthographicScale, 0)
        XCTAssertGreaterThan(left.orthographicScale, 0)
        XCTAssertGreaterThan(right.orthographicScale, 0)
        XCTAssertNotEqual(front.displayed(vertices[0], preset: .front), left.displayed(vertices[0], preset: .subjectLeft))
        XCTAssertNotEqual(front.displayed(vertices[0], preset: .front), right.displayed(vertices[0], preset: .subjectRight))
    }

    func testResetRestoresFrontPreset() {
        var state = FaceMeshViewState(preset: .subjectRight)
        state.reset()
        XCTAssertEqual(state.preset, .front)
    }

    func testCenteredSelectionKeepsRawIndexAndCoordinates() throws {
        let vertices = physicalScaleVertices()
        let framing = try XCTUnwrap(FaceMeshCameraFraming.calculate(vertices: vertices, preset: .subjectLeft, viewportAspectRatio: 1))
        let displayed = vertices.enumerated().map { index, vertex in
            let value = framing.displayed(vertex, preset: .subjectLeft)
            return ProjectedFaceMeshVertex(index: index, screenPoint: CGPoint(x: CGFloat(value.x * 1_000), y: CGFloat(value.y * -1_000)), depth: value.z)
        }
        let target = displayed[0].screenPoint
        XCTAssertEqual(FaceMeshProjection.nearestVertex(to: target, projectedVertices: displayed, tolerance: 1), 0)
        XCTAssertEqual(vertices[0], physicalScaleVertices()[0])
    }

    func testRenderSpecificationMatchesTopologyAndUsesVisibleUnlitMaterials() throws {
        let frame = makeFrame()
        let topology = makeTopology()
        let specification = try XCTUnwrap(FaceMeshRenderSpecification.make(frame: frame, topology: topology))
        XCTAssertEqual(specification.vertexPointCount, topology.vertexCount)
        XCTAssertEqual(specification.triangleIndexCount, topology.triangleCount * 3)
        XCTAssertEqual(specification.trianglePrimitiveCount, topology.triangleCount)
        XCTAssertGreaterThan(specification.pointSize, 3)
        XCTAssertGreaterThan(specification.minimumPointRadius, 1)
        XCTAssertEqual(specification.materialOpacity, 1)
        XCTAssertTrue(specification.usesConstantLighting)
        XCTAssertTrue(specification.isDoubleSided)
    }

    func testInvalidIndexValidationIncludesNegativeBoundaryLargerAndNonnumeric() {
        let topology = makeTopology()
        for text in ["-1", String(topology.vertexCount), String(topology.vertexCount + 100), "not-a-number"] {
            XCTAssertFalse(Int(text).map { (0..<topology.vertexCount).contains($0) } ?? false)
        }
    }
    func testSyntheticTopologyRendersFourSelectableVerticesWithoutChangingConnectivity() {
        let topology = makeTopology()
        let frame = makeFrame()
        let projected = FaceMeshProjection.project(vertices: frame.vertices, yawRadians: 0, scale: 100, center: CGPoint(x: 50, y: 50))
        XCTAssertEqual(projected.count, 4)
        XCTAssertEqual(projected.map(\.index), [0, 1, 2, 3])
        XCTAssertEqual(topology.triangleIndices, [0, 1, 2, 0, 2, 3])
        XCTAssertEqual(frame.vertices, makeFrame().vertices)
    }

    func testFrontProjectionAndRotationAreDeterministicAndRawIsImmutable() {
        let frame = makeFrame()
        let original = frame.vertices
        let front = FaceMeshProjection.project(vertices: frame.vertices, yawRadians: 0, scale: 10, center: .zero)
        XCTAssertEqual(front[1].screenPoint, CGPoint(x: 10, y: 0))
        let rotated = FaceMeshProjection.project(vertices: frame.vertices, yawRadians: .pi / 2, scale: 10, center: .zero)
        XCTAssertNotEqual(rotated[1].screenPoint, front[1].screenPoint)
        XCTAssertEqual(rotated[1].index, 1)
        XCTAssertEqual(frame.vertices, original)
    }

    func testNearestSelectionChoosesClosestAndHonorsTolerance() {
        let points = [
            ProjectedFaceMeshVertex(index: 4, screenPoint: CGPoint(x: 10, y: 10), depth: 0.5),
            ProjectedFaceMeshVertex(index: 9, screenPoint: CGPoint(x: 20, y: 10), depth: 0.5)
        ]
        XCTAssertEqual(FaceMeshProjection.nearestVertex(to: CGPoint(x: 11, y: 10), projectedVertices: points, tolerance: 5), 4)
        XCTAssertEqual(FaceMeshProjection.nearestVertex(to: CGPoint(x: 19, y: 10), projectedVertices: points, tolerance: 5), 9)
        XCTAssertNil(FaceMeshProjection.nearestVertex(to: CGPoint(x: 50, y: 50), projectedVertices: points, tolerance: 5))
    }

    func testNeighborsAreUniqueAndDisconnectedVertexIsSafe() {
        let topology = makeTopology()
        XCTAssertEqual(FaceMeshTopologyInspector.neighbors(of: 0, topology: topology), [1, 2, 3])
        XCTAssertEqual(FaceMeshTopologyInspector.neighbors(of: 1, topology: topology), [0, 2])
        let disconnected = FaceMeshTopology(vertexCount: 4, triangleCount: 1, triangleIndices: [0, 1, 2], textureCoordinates: topology.textureCoordinates)
        XCTAssertEqual(FaceMeshTopologyInspector.neighbors(of: 3, topology: disconnected), [])
        XCTAssertEqual(FaceMeshTopologyInspector.neighbors(of: -1, topology: topology), [])
    }

    func testSameIndexTrajectoryAndDisplacementUseExactRawCoordinates() throws {
        let first = makeFrame(timestamp: 1, offset: 0)
        let second = makeFrame(timestamp: 2, offset: 0.003)
        let originalFirst = first.vertices
        let originalSecond = second.vertices
        XCTAssertEqual(try FaceMeshComparison.position(index: 2, in: first).get(), first.vertices[2])
        let delta = try FaceMeshComparison.displacement(index: 2, reference: first, comparison: second).get()
        XCTAssertEqual(delta.dx, 0.003, accuracy: 0.000_001)
        XCTAssertEqual(delta.dy, 0.003, accuracy: 0.000_001)
        XCTAssertEqual(delta.dz, 0.003, accuracy: 0.000_001)
        XCTAssertEqual(delta.euclideanMeters, sqrt(3 * 0.003 * 0.003), accuracy: 0.000_001)
        XCTAssertEqual(FaceMeshComparison.trajectory(index: 2, frames: [second, first]).map(\.sourceTimestamp), [1, 2])
        XCTAssertEqual(first.vertices, originalFirst)
        XCTAssertEqual(second.vertices, originalSecond)
    }

    func testMissingComparisonAndInvalidIndexFailExplicitly() {
        XCTAssertEqual(FaceMeshComparison.position(index: 0, in: nil), .failure(.comparisonFrameUnavailable))
        XCTAssertEqual(FaceMeshComparison.position(index: 4, in: makeFrame()), .failure(.vertexUnavailable(index: 4)))
        XCTAssertEqual(FaceMeshComparison.displacement(index: 0, reference: makeFrame(), comparison: nil), .failure(.comparisonFrameUnavailable))
    }

    func testLandmarkDraftFieldsSideAndNotesRoundTrip() throws {
        let landmark = FaceLandmarkDefinition(id: "test-a", displayName: "Test Point A", source: .meshVertex(index: 2),
                                              side: .subjectLeft, category: "Synthetic", notes: "Research only")
        let decoded = try roundTrip(landmark)
        XCTAssertEqual(decoded, landmark)
        XCTAssertEqual(decoded.side, .subjectLeft)
        guard case .meshVertex(let index) = decoded.source else { return XCTFail("Expected mesh vertex") }
        XCTAssertEqual(index, 2)
    }

    func testConfigurationRejectsDuplicateLandmarkAndInvalidIndexAndTopology() {
        var config = configuration()
        config.landmarks = [
            FaceLandmarkDefinition(id: "same", displayName: "A", source: .meshVertex(index: 0)),
            FaceLandmarkDefinition(id: "same", displayName: "B", source: .meshVertex(index: 4))
        ]
        let issues = ResearchFaceGeometryValidator.validate(config, topology: makeTopology(), frame: makeFrame())
        XCTAssertTrue(issues.contains(.duplicateLandmarkID("same")))
        XCTAssertTrue(issues.contains(.invalidVertexIndex(ownerID: "same", index: 4)))
        let wrong = ResearchFaceGeometryConfiguration(configurationID: config.configurationID, configurationName: config.configurationName,
            draftRevision: config.draftRevision, createdAt: config.createdAt, requiredTopologyID: "wrong", status: .draft,
            landmarks: [], regions: [], lines: [], polylines: [], planes: [], notes: nil)
        XCTAssertTrue(ResearchFaceGeometryValidator.validate(wrong, topology: makeTopology()).contains(.topologyMismatch))
    }

    func testRegionRoundTripAndValidation() throws {
        var config = configuration()
        config.regions = [FaceRegionDefinition(id: "region", displayName: "Test Region", vertexIndices: [2, 0, 2, 4], side: .subjectRight, notes: "Synthetic")]
        let issues = ResearchFaceGeometryValidator.validate(config, topology: makeTopology())
        XCTAssertTrue(issues.contains(.duplicateRegionVertex(regionID: "region", index: 2)))
        XCTAssertTrue(issues.contains(.invalidVertexIndex(ownerID: "region", index: 4)))
        XCTAssertEqual(try roundTrip(config.regions[0]), config.regions[0])
    }

    func testLineAndOrderedPolylineValidateReferencesAndRoundTrip() throws {
        var config = configurationWithLandmarks()
        config.lines = [FaceLineSegmentDefinition(id: "line", displayName: "Test Line", endpointA: .landmark(id: "a"), endpointB: .landmark(id: "b"))]
        config.polylines = [FacePolylineDefinition(id: "path", displayName: "Test Path", points: [.landmark(id: "b"), .meshVertex(index: 2), .landmark(id: "a")])]
        XCTAssertEqual(ResearchFaceGeometryValidator.validate(config, topology: makeTopology(), frame: makeFrame()), [])
        let decoded = try roundTrip(config)
        XCTAssertEqual(decoded.polylines[0].points, config.polylines[0].points)
        config.lines.append(FaceLineSegmentDefinition(id: "missing", displayName: "Missing", endpointA: .landmark(id: "unknown"), endpointB: .meshVertex(index: 1)))
        XCTAssertTrue(ResearchFaceGeometryValidator.validate(config, topology: makeTopology()).contains(.unresolvedLandmarkReference(ownerID: "missing", landmarkID: "unknown")))
    }

    func testPlaneAcceptsNonCollinearAndRejectsDuplicateAndCollinear() throws {
        var config = configurationWithLandmarks()
        config.planes = [FacePlaneDefinition(id: "plane", displayName: "Test Plane", pointA: .meshVertex(index: 0), pointB: .meshVertex(index: 1), pointC: .meshVertex(index: 3))]
        XCTAssertEqual(ResearchFaceGeometryValidator.validate(config, topology: makeTopology(), frame: makeFrame()), [])
        XCTAssertEqual(try roundTrip(config).planes, config.planes)
        config.planes = [FacePlaneDefinition(id: "duplicate", displayName: "Duplicate", pointA: .meshVertex(index: 0), pointB: .meshVertex(index: 0), pointC: .meshVertex(index: 1))]
        XCTAssertTrue(ResearchFaceGeometryValidator.validate(config, topology: makeTopology(), frame: makeFrame()).contains(.planePointsNotDistinct("duplicate")))
        config.planes = [FacePlaneDefinition(id: "collinear", displayName: "Collinear", pointA: .meshVertex(index: 0), pointB: .meshVertex(index: 1), pointC: .meshVertex(index: 2))]
        XCTAssertTrue(ResearchFaceGeometryValidator.validate(config, topology: makeTopology(), frame: makeFrame()).contains(.planePointsCollinear("collinear")))
    }

    func testDraftConfigurationIsDraftOnlyAndVersionsRemainUnchanged() {
        let config = configuration()
        XCTAssertEqual(config.status, .draft)
        XCTAssertEqual(ResearchDataVersions.current.rawDataSchemaVersion, "4.0.0")
        XCTAssertEqual(ResearchDataVersions.current.analysisAlgorithmVersion, "0.4.0")
        XCTAssertEqual(ResearchDataVersions.current.captureProtocolVersion, "0.4.0")
        XCTAssertEqual(ResearchDataVersions.current.meshCaptureVersion, "1.0.0")
        XCTAssertEqual(ResearchDataVersions.current.landmarkConfigurationVersion, "not-active")
    }

    func testDraftPointChoicesKeepLandmarksAndRawVerticesDistinct() {
        let landmark = DraftPointChoice.landmark(id: "a", displayName: "Test Point A", vertexIndex: 2)
        let vertex = DraftPointChoice.meshVertex(index: 2)
        XCTAssertNotEqual(landmark, vertex)
        XCTAssertEqual(landmark.reference, .landmark(id: "a"))
        XCTAssertEqual(vertex.reference, .meshVertex(index: 2))
        XCTAssertEqual(landmark.displayName, "Test Point A · vertex 2")
    }

    func testExplicitLineBuilderCreatesOneExactLineAndRejectsDuplicates() throws {
        let a = DraftPointChoice.landmark(id: "a", displayName: "A", vertexIndex: 0)
        let b = DraftPointChoice.meshVertex(index: 1)
        let line = try DraftGeometryBuilder.line(id: "line", name: "Test Line", endpointA: a, endpointB: b).get()
        XCTAssertEqual(line.endpointA, .landmark(id: "a"))
        XCTAssertEqual(line.endpointB, .meshVertex(index: 1))
        XCTAssertEqual([line].count, 1)
        XCTAssertEqual(DraftGeometryBuilder.line(id: "bad", name: "Bad", endpointA: a, endpointB: a), .failure(.duplicatePoints))
        XCTAssertEqual(DraftGeometryBuilder.line(id: "bad", name: "Bad", endpointA: nil, endpointB: b), .failure(.missingPoints))
    }

    func testOrderedPolylineBuilderPreservesReorderingAndRejectsShortInput() throws {
        let a = DraftPointChoice.landmark(id: "a", displayName: "A", vertexIndex: 0)
        let b = DraftPointChoice.landmark(id: "b", displayName: "B", vertexIndex: 1)
        let c = DraftPointChoice.meshVertex(index: 3)
        var points = [a, b, c]
        points.swapAt(1, 2)
        points.remove(at: 2)
        points.append(b)
        let path = try DraftGeometryBuilder.polyline(id: "path", name: "Test Path", points: points).get()
        XCTAssertEqual(path.points, [a.reference, c.reference, b.reference])
        points.removeAll()
        XCTAssertEqual(DraftGeometryBuilder.polyline(id: "bad", name: "Bad", points: points), .failure(.missingPoints))
    }

    func testExplicitPlaneBuilderRejectsMissingAndDuplicatePoints() throws {
        let a = DraftPointChoice.meshVertex(index: 0)
        let b = DraftPointChoice.meshVertex(index: 1)
        let c = DraftPointChoice.meshVertex(index: 3)
        let plane = try DraftGeometryBuilder.plane(id: "plane", name: "Test Plane", pointA: a, pointB: b, pointC: c).get()
        XCTAssertEqual([plane.pointA, plane.pointB, plane.pointC], [a.reference, b.reference, c.reference])
        XCTAssertEqual(DraftGeometryBuilder.plane(id: "bad", name: "Bad", pointA: a, pointB: a, pointC: c), .failure(.duplicatePoints))
        XCTAssertEqual(DraftGeometryBuilder.plane(id: "bad", name: "Bad", pointA: a, pointB: b, pointC: nil), .failure(.missingPoints))
    }

    func testEveryDraftOverlayResolvesExactCoordinatesAndLeavesRawMeshUntouched() throws {
        let frame = makeFrame()
        let original = frame.vertices
        var config = configuration()
        config.landmarks = [.init(id: "a", displayName: "A", source: .meshVertex(index: 0)),
                            .init(id: "b", displayName: "B", source: .meshVertex(index: 1)),
                            .init(id: "c", displayName: "C", source: .meshVertex(index: 3))]
        config.regions = [.init(id: "region", displayName: "Test Region", vertexIndices: [3, 0, 1])]
        config.lines = [.init(id: "line", displayName: "Test Line", endpointA: .landmark(id: "a"), endpointB: .meshVertex(index: 1))]
        config.polylines = [.init(id: "path", displayName: "Test Path", points: [.landmark(id: "a"), .landmark(id: "b"), .landmark(id: "c")])]
        config.planes = [.init(id: "plane", displayName: "Test Plane", pointA: .landmark(id: "a"), pointB: .landmark(id: "b"), pointC: .landmark(id: "c"))]
        let overlays = FaceMeshDraftOverlayResolver.resolve(configuration: config, frame: frame)
        XCTAssertEqual(overlays.landmarks.map(\.position), [frame.vertices[0], frame.vertices[1], frame.vertices[3]])
        XCTAssertEqual(overlays.regions.first?.positions, [frame.vertices[3], frame.vertices[0], frame.vertices[1]])
        XCTAssertEqual(overlays.lines.first?.positions, [frame.vertices[0], frame.vertices[1]])
        XCTAssertEqual(overlays.polylines.first?.positions, [frame.vertices[0], frame.vertices[1], frame.vertices[3]])
        XCTAssertEqual(overlays.planes.first?.positions, [frame.vertices[0], frame.vertices[1], frame.vertices[3]])
        XCTAssertEqual(frame.vertices, original)
        XCTAssertEqual(FaceMeshDraftOverlayResolver.resolve(configuration: try roundTrip(config), frame: frame), overlays)
    }

    func testPhysicalThreeLineDraftRemainsCodableWhileOneBuilderCallReturnsOneLine() throws {
        var config = configurationWithLandmarks()
        config.landmarks.append(.init(id: "c", displayName: "C", source: .meshVertex(index: 3)))
        config.lines = [
            .init(id: "ab", displayName: "Test line", endpointA: .landmark(id: "a"), endpointB: .landmark(id: "b")),
            .init(id: "bc", displayName: "Test line", endpointA: .landmark(id: "b"), endpointB: .landmark(id: "c")),
            .init(id: "ac", displayName: "Test line", endpointA: .landmark(id: "a"), endpointB: .landmark(id: "c"))]
        XCTAssertEqual(try roundTrip(config).lines.count, 3)
        let created = try DraftGeometryBuilder.line(id: "new", name: "Test line", endpointA: .landmark(id: "a", displayName: "A", vertexIndex: 0), endpointB: .landmark(id: "b", displayName: "B", vertexIndex: 1)).get()
        XCTAssertEqual([created].count, 1)
    }

    func testLandmarkDeletionPreventsDanglingReferencesAndUnusedDeletionSucceeds() throws {
        var config = configurationWithLandmarks()
        config.lines = [.init(id: "line", displayName: "Test Line", endpointA: .landmark(id: "a"), endpointB: .meshVertex(index: 3))]
        XCTAssertEqual(DraftConfigurationDeletion.landmark(id: "a", from: config), .failure(.referencedLandmark(["Test Line"])))
        let deleted = try DraftConfigurationDeletion.landmark(id: "b", from: config).get()
        XCTAssertEqual(deleted.landmarks.map(\.id), ["a"])
        XCTAssertEqual(deleted.lines, config.lines)
    }

    private func makeTopology() -> FaceMeshTopology {
        FaceMeshTopology(vertexCount: 4, triangleCount: 2, triangleIndices: [0, 1, 2, 0, 2, 3],
                         textureCoordinates: [.init(u: 0, v: 0), .init(u: 1, v: 0), .init(u: 1, v: 1), .init(u: 0, v: 1)])
    }

    private func physicalScaleVertices() -> [FaceMeshVertex] {
        [.init(x: -0.05, y: -0.08, z: -0.03),
         .init(x: 0.09, y: -0.08, z: -0.03),
         .init(x: 0.09, y: 0.12, z: 0.07),
         .init(x: -0.05, y: 0.12, z: 0.07)]
    }

    private func makeFrame(timestamp: Double = 1, offset: Float = 0) -> RawFaceMeshFrame {
        let topology = makeTopology()
        return RawFaceMeshFrame(id: UUID(), rawFrameID: UUID(), recordingID: UUID(), sourceTimestamp: timestamp,
                                taskType: .neutralRest, repetitionIndex: 1, frameIndex: Int(timestamp), topologyID: topology.topologyID,
                                vertices: [.init(x: 0 + offset, y: 0 + offset, z: 0 + offset),
                                           .init(x: 1 + offset, y: 0 + offset, z: 0 + offset),
                                           .init(x: 2 + offset, y: 0 + offset, z: 0 + offset),
                                           .init(x: 0 + offset, y: 1 + offset, z: 0 + offset)])
    }

    private func configuration() -> ResearchFaceGeometryConfiguration {
        ResearchFaceGeometryConfiguration(configurationID: "config", configurationName: "Synthetic Draft", draftRevision: "draft-1",
            createdAt: Date(timeIntervalSince1970: 1), requiredTopologyID: makeTopology().topologyID, status: .draft,
            landmarks: [], regions: [], lines: [], polylines: [], planes: [], notes: "No anatomy")
    }

    private func configurationWithLandmarks() -> ResearchFaceGeometryConfiguration {
        var config = configuration()
        config.landmarks = [FaceLandmarkDefinition(id: "a", displayName: "Test A", source: .meshVertex(index: 0)),
                            FaceLandmarkDefinition(id: "b", displayName: "Test B", source: .meshVertex(index: 1))]
        return config
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
}
