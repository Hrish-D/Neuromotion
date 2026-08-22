import Foundation
import XCTest
@testable import Facework

@MainActor
final class RawSessionPersistenceTests: XCTestCase {
    func testSessionStoreProjectionWritesIndependentAuthoritativeRawFramesFile() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let frame = TestFixtures.frame(
            timestamp: 1.11665,
            raw: ["jawOpen": 0.4],
            normalized: ["jawOpen": 0.3],
            smoothed: ["jawOpen": 0.3],
            imageReference: "/synthetic/validation.jpg"
        )

        let rawURL = directory.url.appendingPathComponent(SessionStore.rawFramesFileName)
        try JSONExporter().export(SessionStore.authoritativeRawFrames(from: [frame]), to: rawURL)
        let rawFrames = try JSONDecoder().decode([RawFrameCapture].self, from: Data(contentsOf: rawURL))
        XCTAssertEqual(rawFrames, [frame.raw])
        XCTAssertEqual(rawFrames.first?.validationImageReference, frame.imageReference)
        XCTAssertEqual(rawURL.lastPathComponent, "raw_frames.json")
    }

    func testMeshFramesAndTopologyUseSeparateStructuredFiles() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let topology = FaceMeshTopology(
            vertexCount: 4,
            triangleCount: 2,
            triangleIndices: [0, 1, 2, 0, 2, 3],
            textureCoordinates: [
                FaceMeshTextureCoordinate(u: 0, v: 0),
                FaceMeshTextureCoordinate(u: 1, v: 0),
                FaceMeshTextureCoordinate(u: 1, v: 1),
                FaceMeshTextureCoordinate(u: 0, v: 1)
            ]
        )
        let mesh = RawFaceMeshFrame(
            id: TestFixtures.deterministicUUID(900),
            rawFrameID: TestFixtures.deterministicUUID(901),
            recordingID: TestFixtures.deterministicUUID(902),
            sourceTimestamp: 10,
            taskType: .browRaise,
            repetitionIndex: 1,
            frameIndex: 0,
            topologyID: topology.topologyID,
            vertices: [
                FaceMeshVertex(x: 0, y: 0, z: 0),
                FaceMeshVertex(x: 1, y: 0, z: 0),
                FaceMeshVertex(x: 1, y: 1, z: 0),
                FaceMeshVertex(x: 0, y: 1, z: 0)
            ]
        )
        let framesURL = directory.url.appendingPathComponent(SessionStore.rawFaceMeshFramesFileName)
        let topologyURL = directory.url.appendingPathComponent(SessionStore.faceMeshTopologyFileName)
        let meshExport = RawFaceMeshFramesExport(frames: [mesh], unavailableFrames: [])
        try JSONExporter().export(meshExport, to: framesURL)
        try JSONExporter().export(topology, to: topologyURL)

        XCTAssertEqual(
            try JSONDecoder().decode(RawFaceMeshFramesExport.self, from: Data(contentsOf: framesURL)),
            meshExport
        )
        XCTAssertEqual(
            try JSONDecoder().decode(FaceMeshTopology.self, from: Data(contentsOf: topologyURL)),
            topology
        )
        let dynamicJSON = try String(contentsOf: framesURL, encoding: .utf8)
        XCTAssertFalse(dynamicJSON.contains("triangleIndices"))
        XCTAssertFalse(dynamicJSON.contains("textureCoordinates"))
        XCTAssertEqual(framesURL.lastPathComponent, "raw_face_mesh_frames.json")
        XCTAssertEqual(topologyURL.lastPathComponent, "face_mesh_topology.json")

        print(
            "PROMPT11_SYNTHETIC_EXPORT meshFrameBytes=\((try Data(contentsOf: framesURL)).count) " +
            "topologyBytes=\((try Data(contentsOf: topologyURL)).count)"
        )
    }
}
