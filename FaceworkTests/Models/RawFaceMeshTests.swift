import Foundation
import ARKit
import XCTest
@testable import Facework

@MainActor
final class RawFaceMeshTests: XCTestCase {
    func testInstalledSDKNeutralGeometryReportsRuntimeShape() throws {
        let geometry = try XCTUnwrap(ARFaceGeometry(blendShapes: [:]))
        XCTAssertEqual(geometry.vertices.count, geometry.textureCoordinates.count)
        XCTAssertEqual(geometry.triangleIndices.count, geometry.triangleCount * 3)
        print(
            "PROMPT11_RUNTIME_GEOMETRY vertexCount=\(geometry.vertices.count) " +
            "triangleCount=\(geometry.triangleCount) " +
            "textureCoordinateCount=\(geometry.textureCoordinates.count)"
        )
    }

    func testTopologyIdentityUsesOnlyConstantTopology() throws {
        let first = topology()
        let second = topology()
        XCTAssertEqual(first.topologyID, second.topologyID)

        let changedIndex = FaceMeshTopology(
            vertexCount: 4,
            triangleCount: 2,
            triangleIndices: [0, 1, 3, 0, 2, 3],
            textureCoordinates: textureCoordinates()
        )
        XCTAssertNotEqual(first.topologyID, changedIndex.topologyID)

        let frameA = snapshot(timestamp: 1, offset: 0, topology: first)
        let frameB = snapshot(timestamp: 2, offset: 10, topology: first)
        XCTAssertEqual(frameA.topology.topologyID, frameB.topology.topologyID)
        XCTAssertNotEqual(frameA.vertices, frameB.vertices)
    }

    func testTopologyAndVerticesRoundTripExactly() throws {
        let sourceTopology = topology()
        let decodedTopology = try roundTrip(sourceTopology)
        XCTAssertEqual(decodedTopology, sourceTopology)
        XCTAssertEqual(decodedTopology.vertexCount, 4)
        XCTAssertEqual(decodedTopology.triangleCount, 2)
        XCTAssertEqual(decodedTopology.triangleIndices, [0, 1, 2, 0, 2, 3])

        let raw = rawFrame(timestamp: 10, frameIndex: 0)
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: raw, snapshot: snapshot(timestamp: 10, offset: 0))
        let decodedFrame = try roundTrip(XCTUnwrap(accumulator.frames.first))
        XCTAssertEqual(decodedFrame, accumulator.frames.first)
        XCTAssertEqual(decodedFrame.vertices[2], FaceMeshVertex(x: 2, y: 2.5, z: -2))
    }

    func testAcceptedFrameLinksAllRawContextAndTimestamp() throws {
        let raw = rawFrame(timestamp: 10, frameIndex: 7, task: .smileTeeth, repetition: 2)
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: raw, snapshot: snapshot(timestamp: 10, offset: 0))
        let mesh = try XCTUnwrap(accumulator.frames.first)
        XCTAssertEqual(mesh.rawFrameID, raw.id)
        XCTAssertEqual(mesh.recordingID, raw.recordingID)
        XCTAssertEqual(mesh.sourceTimestamp, raw.sourceTimestamp)
        XCTAssertEqual(mesh.taskType, raw.taskType)
        XCTAssertEqual(mesh.repetitionIndex, raw.repetitionIndex)
        XCTAssertEqual(mesh.frameIndex, raw.frameIndex)
    }

    func testMissingGeometryKeepsRawFrameAndDoesNotFabricateVertices() throws {
        let raw = rawFrame(timestamp: 1, frameIndex: 0)
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: raw, snapshot: nil)
        XCTAssertTrue(accumulator.frames.isEmpty)
        XCTAssertEqual(accumulator.unavailableFrames.first?.rawFrameID, raw.id)
        XCTAssertEqual(accumulator.unavailableFrames.first?.reason, .missingGeometry)
        XCTAssertEqual(raw.sourceTimestamp, 1)
    }

    func testVertexCountMismatchIsUnavailable() {
        let raw = rawFrame(timestamp: 1, frameIndex: 0)
        let invalid = FaceMeshSnapshot(
            sourceTimestamp: 1,
            topology: topology(),
            vertices: [FaceMeshVertex(x: 0, y: 0, z: 0)]
        )
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: raw, snapshot: invalid)
        XCTAssertTrue(accumulator.frames.isEmpty)
        XCTAssertEqual(accumulator.unavailableFrames.first?.reason, .invalidGeometry)
    }

    func testTopologyMismatchCannotMixSeries() {
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: rawFrame(timestamp: 1, frameIndex: 0), snapshot: snapshot(timestamp: 1, offset: 0))
        let changed = FaceMeshTopology(
            vertexCount: 4,
            triangleCount: 2,
            triangleIndices: [0, 1, 3, 0, 2, 3],
            textureCoordinates: textureCoordinates()
        )
        accumulator.record(
            rawFrame: rawFrame(timestamp: 1.1, frameIndex: 1),
            snapshot: snapshot(timestamp: 1.1, offset: 0, topology: changed)
        )
        XCTAssertEqual(accumulator.frames.count, 1)
        XCTAssertEqual(accumulator.unavailableFrames.last?.reason, .incompatibleTopology)
    }

    func testExportValidatorDetectsAssociationFailures() throws {
        let raw = rawFrame(timestamp: 1, frameIndex: 0)
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: raw, snapshot: snapshot(timestamp: 1, offset: 0))
        XCTAssertEqual(FaceMeshExportValidator.validate(
            rawFrames: [raw], meshFrames: accumulator.frames,
            unavailableFrames: accumulator.unavailableFrames, topology: accumulator.topology
        ), [])

        let mesh = try XCTUnwrap(accumulator.frames.first)
        let wrongTimestamp = RawFaceMeshFrame(
            id: mesh.id, rawFrameID: mesh.rawFrameID, recordingID: mesh.recordingID,
            sourceTimestamp: 2, taskType: mesh.taskType, repetitionIndex: mesh.repetitionIndex,
            frameIndex: mesh.frameIndex, topologyID: mesh.topologyID, vertices: mesh.vertices
        )
        XCTAssertTrue(FaceMeshExportValidator.validate(
            rawFrames: [raw], meshFrames: [wrongTimestamp], topology: accumulator.topology
        ).contains(.timestampMismatch(rawFrameID: raw.id)))
    }

    func testGenericLandmarkExtractionIsExactAtBoundaries() throws {
        let topology = topology()
        let raw = rawFrame(timestamp: 1, frameIndex: 0)
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: raw, snapshot: snapshot(timestamp: 1, offset: 0, topology: topology))
        let mesh = try XCTUnwrap(accumulator.frames.first)
        let configuration = FaceLandmarkConfiguration(
            configurationID: "synthetic-config",
            configurationVersion: "test-only",
            requiredTopologyID: topology.topologyID,
            definitions: [
                FaceLandmarkDefinition(id: "syntheticLandmarkA", displayName: "Synthetic A", source: .meshVertex(index: 0)),
                FaceLandmarkDefinition(id: "syntheticLandmarkB", displayName: "Synthetic B", source: .meshVertex(index: 3))
            ]
        )
        XCTAssertEqual(FaceLandmarkExtractor.validate(configuration: configuration, topology: topology), [])
        let extracted = try FaceLandmarkExtractor.extract(
            frame: mesh, topology: topology, configuration: configuration
        ).get()
        XCTAssertEqual(extracted.map(\.position), [mesh.vertices[0], mesh.vertices[3]])
        XCTAssertEqual(try roundTrip(configuration), configuration)
    }

    func testInvalidLandmarkIndexesDuplicatesAndTopologyFailSafely() throws {
        let topology = topology()
        let invalid = FaceLandmarkConfiguration(
            configurationID: "synthetic-invalid",
            configurationVersion: "test-only",
            requiredTopologyID: "wrong-topology",
            definitions: [
                FaceLandmarkDefinition(id: "duplicate", displayName: "Negative", source: .meshVertex(index: -1)),
                FaceLandmarkDefinition(id: "duplicate", displayName: "Past End", source: .meshVertex(index: 4))
            ]
        )
        let issues = FaceLandmarkExtractor.validate(configuration: invalid, topology: topology)
        XCTAssertTrue(issues.contains(.topologyMismatch))
        XCTAssertTrue(issues.contains(.duplicateLandmarkID("duplicate")))
        XCTAssertTrue(issues.contains(.invalidVertexIndex(landmarkID: "duplicate", index: -1)))
        XCTAssertTrue(issues.contains(.invalidVertexIndex(landmarkID: "duplicate", index: 4)))
    }

    func testRawMeshSurvivesDerivedSignalSpike() throws {
        let raw = rawFrame(timestamp: 1, frameIndex: 0)
        var accumulator = FaceMeshSessionAccumulator()
        accumulator.record(rawFrame: raw, snapshot: snapshot(timestamp: 1, offset: 0))
        let derived = FrameCapture(
            raw: raw,
            analysis: FrameAnalysis(
                normalizedBlendshapes: [:], smoothedBlendshapes: [:],
                qcFlags: [.signalSpike], isValidFrame: false
            )
        )
        XCTAssertTrue(derived.qcFlags.contains(.signalSpike))
        XCTAssertEqual(accumulator.frames.first?.rawFrameID, raw.id)
    }

    private func topology() -> FaceMeshTopology {
        FaceMeshTopology(
            vertexCount: 4,
            triangleCount: 2,
            triangleIndices: [0, 1, 2, 0, 2, 3],
            textureCoordinates: textureCoordinates()
        )
    }

    private func textureCoordinates() -> [FaceMeshTextureCoordinate] {
        [
            FaceMeshTextureCoordinate(u: 0, v: 0),
            FaceMeshTextureCoordinate(u: 1, v: 0),
            FaceMeshTextureCoordinate(u: 1, v: 1),
            FaceMeshTextureCoordinate(u: 0, v: 1)
        ]
    }

    private func snapshot(
        timestamp: TimeInterval,
        offset: Float,
        topology: FaceMeshTopology? = nil
    ) -> FaceMeshSnapshot {
        FaceMeshSnapshot(
            sourceTimestamp: timestamp,
            topology: topology ?? self.topology(),
            vertices: (0..<4).map {
                FaceMeshVertex(x: Float($0) + offset, y: Float($0) + 0.5 + offset, z: -Float($0) - offset)
            }
        )
    }

    private func rawFrame(
        timestamp: TimeInterval,
        frameIndex: Int,
        task: TaskType = .browRaise,
        repetition: Int = 1
    ) -> RawFrameCapture {
        RawFrameCapture(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, UInt8(frameIndex), 1)),
            recordingID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, UInt8(frameIndex), 1)),
            frameIndex: frameIndex,
            sourceTimestamp: timestamp, taskType: task, repetitionIndex: repetition,
            rawBlendshapes: ["jawOpen": 0.1], faceTransform: nil, headPose: nil,
            faceIsPresent: true, visibleFaceCount: 1, faceTrackingState: .tracking,
            faceCenter: nil, faceScale: nil, cameraTrackingStateAtCapture: "normal",
            isNeutralPhase: false, validationImageReference: nil
        )
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
}
