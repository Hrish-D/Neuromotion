import CryptoKit
import Foundation
import simd

/// An unmodified ARKit face-geometry position in face-anchor coordinates.
/// Values use ARKit's native Float/meter semantics. Positive X is viewer-right
/// (subject-left); no side reversal or coordinate conversion is applied.
nonisolated struct FaceMeshVertex: Codable, Equatable, Sendable {
    let x: Float
    let y: Float
    let z: Float

    nonisolated init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    nonisolated init(_ value: SIMD3<Float>) {
        self.init(x: value.x, y: value.y, z: value.z)
    }

    nonisolated var simdValue: SIMD3<Float> { SIMD3(x, y, z) }
}

nonisolated struct FaceMeshTextureCoordinate: Codable, Equatable, Sendable {
    let u: Float
    let v: Float

    nonisolated init(u: Float, v: Float) {
        self.u = u
        self.v = v
    }

    nonisolated init(_ value: SIMD2<Float>) {
        self.init(u: value.x, v: value.y)
    }
}

/// Facework provenance identity for constant ARKit face-mesh topology.
/// The SHA-256 input is: ASCII domain/version marker, then little-endian
/// UInt64 counts, little-endian signed Int16 indices, and the little-endian
/// IEEE-754 bit patterns of texture-coordinate Floats.
nonisolated struct FaceMeshTopology: Codable, Equatable, Sendable {
    let topologyID: String
    let vertexCount: Int
    let triangleCount: Int
    let triangleIndices: [Int16]
    let textureCoordinates: [FaceMeshTextureCoordinate]

    init(
        vertexCount: Int,
        triangleCount: Int,
        triangleIndices: [Int16],
        textureCoordinates: [FaceMeshTextureCoordinate]
    ) {
        self.vertexCount = vertexCount
        self.triangleCount = triangleCount
        self.triangleIndices = triangleIndices
        self.textureCoordinates = textureCoordinates
        topologyID = Self.identity(
            vertexCount: vertexCount,
            triangleCount: triangleCount,
            triangleIndices: triangleIndices,
            textureCoordinates: textureCoordinates
        )
    }

    var isStructurallyValid: Bool {
        vertexCount >= 0 && triangleCount >= 0 &&
        triangleIndices.count == triangleCount * 3 &&
        textureCoordinates.count == vertexCount
    }

    static func identity(
        vertexCount: Int,
        triangleCount: Int,
        triangleIndices: [Int16],
        textureCoordinates: [FaceMeshTextureCoordinate]
    ) -> String {
        var bytes = Array("facework-face-mesh-topology-v1\0".utf8)
        bytes.appendLittleEndian(UInt64(vertexCount))
        bytes.appendLittleEndian(UInt64(triangleCount))
        for index in triangleIndices {
            bytes.appendLittleEndian(UInt16(bitPattern: index))
        }
        for coordinate in textureCoordinates {
            bytes.appendLittleEndian(coordinate.u.bitPattern)
            bytes.appendLittleEndian(coordinate.v.bitPattern)
        }
        let digest = SHA256.hash(data: Data(bytes))
        let hex = digest.map { byte -> String in
            let value = String(byte, radix: 16)
            return value.count == 1 ? "0" + value : value
        }.joined()
        return "facework-sha256-v1:" + hex
    }
}

/// Fully owned values copied synchronously from one ARFaceGeometry instance.
/// This transient value contains no ARKit reference object.
nonisolated struct FaceMeshSnapshot: Equatable, Sendable {
    let sourceTimestamp: TimeInterval
    let topology: FaceMeshTopology
    let vertices: [FaceMeshVertex]

    var isStructurallyValid: Bool {
        topology.isStructurallyValid && vertices.count == topology.vertexCount
    }
}

nonisolated struct RawFaceMeshFrame: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let rawFrameID: UUID
    let recordingID: UUID
    let sourceTimestamp: TimeInterval
    let taskType: TaskType
    let repetitionIndex: Int
    let frameIndex: Int
    let topologyID: String
    let vertices: [FaceMeshVertex]
}

nonisolated enum RawFaceMeshAvailability: String, Codable, Equatable, Sendable {
    case available
    case missingGeometry
    case invalidGeometry
    case incompatibleTopology
}

nonisolated struct RawFaceMeshUnavailableFrame: Codable, Equatable, Sendable {
    let rawFrameID: UUID
    let recordingID: UUID?
    let sourceTimestamp: TimeInterval
    let taskType: TaskType
    let repetitionIndex: Int
    let frameIndex: Int
    let reason: RawFaceMeshAvailability
    let observedTopologyID: String?
}

nonisolated struct RawFaceMeshFramesExport: Codable, Equatable, Sendable {
    let frames: [RawFaceMeshFrame]
    let unavailableFrames: [RawFaceMeshUnavailableFrame]
}

struct FaceMeshSessionAccumulator {
    private(set) var topology: FaceMeshTopology?
    private(set) var frames: [RawFaceMeshFrame] = []
    private(set) var unavailableFrames: [RawFaceMeshUnavailableFrame] = []

    mutating func record(rawFrame: RawFrameCapture, snapshot: FaceMeshSnapshot?) {
        guard let snapshot else {
            recordUnavailable(rawFrame: rawFrame, reason: .missingGeometry, observedTopologyID: nil)
            return
        }
        guard snapshot.sourceTimestamp == rawFrame.sourceTimestamp,
              snapshot.isStructurallyValid else {
            recordUnavailable(
                rawFrame: rawFrame,
                reason: .invalidGeometry,
                observedTopologyID: snapshot.topology.topologyID
            )
            return
        }
        if let topology, topology.topologyID != snapshot.topology.topologyID {
            recordUnavailable(
                rawFrame: rawFrame,
                reason: .incompatibleTopology,
                observedTopologyID: snapshot.topology.topologyID
            )
            return
        }
        guard let recordingID = rawFrame.recordingID else {
            recordUnavailable(
                rawFrame: rawFrame,
                reason: .invalidGeometry,
                observedTopologyID: snapshot.topology.topologyID
            )
            return
        }
        if topology == nil { topology = snapshot.topology }
        frames.append(RawFaceMeshFrame(
            id: UUID(),
            rawFrameID: rawFrame.id,
            recordingID: recordingID,
            sourceTimestamp: rawFrame.sourceTimestamp,
            taskType: rawFrame.taskType,
            repetitionIndex: rawFrame.repetitionIndex,
            frameIndex: rawFrame.frameIndex,
            topologyID: snapshot.topology.topologyID,
            vertices: snapshot.vertices
        ))
    }

    private mutating func recordUnavailable(
        rawFrame: RawFrameCapture,
        reason: RawFaceMeshAvailability,
        observedTopologyID: String?
    ) {
        unavailableFrames.append(RawFaceMeshUnavailableFrame(
            rawFrameID: rawFrame.id,
            recordingID: rawFrame.recordingID,
            sourceTimestamp: rawFrame.sourceTimestamp,
            taskType: rawFrame.taskType,
            repetitionIndex: rawFrame.repetitionIndex,
            frameIndex: rawFrame.frameIndex,
            reason: reason,
            observedTopologyID: observedTopologyID
        ))
    }
}

nonisolated struct FaceMeshCaptureSummary: Codable, Equatable, Sendable {
    let topologyID: String?
    let vertexCount: Int?
    let triangleCount: Int?
    let rawFrameCount: Int
    let meshFrameCount: Int
    let missingMeshFrameCount: Int
}

nonisolated enum FaceMeshValidationIssue: Equatable, Sendable {
    case missingRawFrame(rawFrameID: UUID)
    case timestampMismatch(rawFrameID: UUID)
    case recordingMismatch(rawFrameID: UUID)
    case contextMismatch(rawFrameID: UUID)
    case topologyMismatch(rawFrameID: UUID)
    case vertexCountMismatch(rawFrameID: UUID)
    case missingMeshDisposition(rawFrameID: UUID)
    case duplicateMeshDisposition(rawFrameID: UUID)
    case unavailableContextMismatch(rawFrameID: UUID)
}

nonisolated enum FaceMeshExportValidator {
    static func validate(
        rawFrames: [RawFrameCapture],
        meshFrames: [RawFaceMeshFrame],
        unavailableFrames: [RawFaceMeshUnavailableFrame] = [],
        topology: FaceMeshTopology?
    ) -> [FaceMeshValidationIssue] {
        let rawByID = Dictionary(uniqueKeysWithValues: rawFrames.map { ($0.id, $0) })
        var issues: [FaceMeshValidationIssue] = []
        let meshCounts = Dictionary(grouping: meshFrames, by: \.rawFrameID).mapValues(\.count)
        let unavailableCounts = Dictionary(grouping: unavailableFrames, by: \.rawFrameID).mapValues(\.count)
        for raw in rawFrames {
            let dispositionCount = (meshCounts[raw.id] ?? 0) + (unavailableCounts[raw.id] ?? 0)
            if dispositionCount == 0 {
                issues.append(.missingMeshDisposition(rawFrameID: raw.id))
            } else if dispositionCount > 1 {
                issues.append(.duplicateMeshDisposition(rawFrameID: raw.id))
            }
        }
        for mesh in meshFrames {
            guard let raw = rawByID[mesh.rawFrameID] else {
                issues.append(.missingRawFrame(rawFrameID: mesh.rawFrameID))
                continue
            }
            if raw.sourceTimestamp != mesh.sourceTimestamp {
                issues.append(.timestampMismatch(rawFrameID: mesh.rawFrameID))
            }
            if raw.recordingID != mesh.recordingID {
                issues.append(.recordingMismatch(rawFrameID: mesh.rawFrameID))
            }
            if raw.taskType != mesh.taskType || raw.repetitionIndex != mesh.repetitionIndex ||
                raw.frameIndex != mesh.frameIndex {
                issues.append(.contextMismatch(rawFrameID: mesh.rawFrameID))
            }
            guard let topology else {
                issues.append(.topologyMismatch(rawFrameID: mesh.rawFrameID))
                continue
            }
            if mesh.topologyID != topology.topologyID {
                issues.append(.topologyMismatch(rawFrameID: mesh.rawFrameID))
            }
            if mesh.vertices.count != topology.vertexCount {
                issues.append(.vertexCountMismatch(rawFrameID: mesh.rawFrameID))
            }
        }
        for unavailable in unavailableFrames {
            guard let raw = rawByID[unavailable.rawFrameID] else {
                issues.append(.missingRawFrame(rawFrameID: unavailable.rawFrameID))
                continue
            }
            if raw.recordingID != unavailable.recordingID ||
                raw.sourceTimestamp != unavailable.sourceTimestamp ||
                raw.taskType != unavailable.taskType ||
                raw.repetitionIndex != unavailable.repetitionIndex ||
                raw.frameIndex != unavailable.frameIndex {
                issues.append(.unavailableContextMismatch(rawFrameID: unavailable.rawFrameID))
            }
        }
        return issues
    }
}

private extension Array where Element == UInt8 {
    nonisolated mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        let encoded = value.littleEndian
        for byteIndex in 0..<MemoryLayout<T>.size {
            append(UInt8(truncatingIfNeeded: encoded >> (byteIndex * 8)))
        }
    }
}
