import CoreGraphics
import Foundation
import simd

nonisolated enum DraftPointChoice: Hashable, Identifiable, Sendable {
    case landmark(id: String, displayName: String, vertexIndex: Int)
    case meshVertex(index: Int)

    var id: String {
        switch self {
        case .landmark(let id, _, _): return "landmark:\(id)"
        case .meshVertex(let index): return "vertex:\(index)"
        }
    }

    var reference: FaceGeometryPointReference {
        switch self {
        case .landmark(let id, _, _): return .landmark(id: id)
        case .meshVertex(let index): return .meshVertex(index: index)
        }
    }

    var vertexIndex: Int {
        switch self {
        case .landmark(_, _, let index), .meshVertex(let index): return index
        }
    }

    var displayName: String {
        switch self {
        case .landmark(_, let name, let index): return "\(name) · vertex \(index)"
        case .meshVertex(let index): return "Vertex \(index)"
        }
    }
}

nonisolated struct FaceMeshDraftOverlays: Equatable, Sendable {
    struct Landmark: Equatable, Sendable { let id: String; let name: String; let index: Int; let position: FaceMeshVertex }
    struct Region: Equatable, Sendable { let id: String; let name: String; let indices: [Int]; let positions: [FaceMeshVertex] }
    struct Path: Equatable, Sendable { let id: String; let name: String; let positions: [FaceMeshVertex] }
    struct Plane: Equatable, Sendable { let id: String; let name: String; let positions: [FaceMeshVertex] }

    let landmarks: [Landmark]
    let regions: [Region]
    let lines: [Path]
    let polylines: [Path]
    let planes: [Plane]

    static let empty = FaceMeshDraftOverlays(landmarks: [], regions: [], lines: [], polylines: [], planes: [])
}

nonisolated enum FaceMeshDraftOverlayResolver {
    static func resolve(configuration: ResearchFaceGeometryConfiguration?, frame: RawFaceMeshFrame) -> FaceMeshDraftOverlays {
        guard let configuration, configuration.requiredTopologyID == frame.topologyID else { return .empty }
        let landmarkByID = Dictionary(uniqueKeysWithValues: configuration.landmarks.map { ($0.id, $0) })
        func position(_ reference: FaceGeometryPointReference) -> FaceMeshVertex? {
            let index: Int
            switch reference {
            case .meshVertex(let value): index = value
            case .landmark(let id):
                guard case .meshVertex(let value)? = landmarkByID[id]?.source else { return nil }
                index = value
            }
            return frame.vertices.indices.contains(index) ? frame.vertices[index] : nil
        }
        let landmarks = configuration.landmarks.compactMap { landmark -> FaceMeshDraftOverlays.Landmark? in
            guard case .meshVertex(let index) = landmark.source, frame.vertices.indices.contains(index) else { return nil }
            return .init(id: landmark.id, name: landmark.displayName, index: index, position: frame.vertices[index])
        }
        let regions = configuration.regions.compactMap { region -> FaceMeshDraftOverlays.Region? in
            let positions = region.vertexIndices.compactMap { frame.vertices.indices.contains($0) ? frame.vertices[$0] : nil }
            guard positions.count == region.vertexIndices.count else { return nil }
            return .init(id: region.id, name: region.displayName, indices: region.vertexIndices, positions: positions)
        }
        let lines = configuration.lines.compactMap { line -> FaceMeshDraftOverlays.Path? in
            guard let a = position(line.endpointA), let b = position(line.endpointB) else { return nil }
            return .init(id: line.id, name: line.displayName, positions: [a, b])
        }
        let polylines = configuration.polylines.compactMap { path -> FaceMeshDraftOverlays.Path? in
            let positions = path.points.compactMap(position)
            guard positions.count == path.points.count else { return nil }
            return .init(id: path.id, name: path.displayName, positions: positions)
        }
        let planes = configuration.planes.compactMap { plane -> FaceMeshDraftOverlays.Plane? in
            let positions = [plane.pointA, plane.pointB, plane.pointC].compactMap(position)
            guard positions.count == 3 else { return nil }
            return .init(id: plane.id, name: plane.displayName, positions: positions)
        }
        return .init(landmarks: landmarks, regions: regions, lines: lines, polylines: polylines, planes: planes)
    }
}

nonisolated enum DraftGeometryBuilderError: Error, Equatable, Sendable {
    case missingPoints
    case duplicatePoints
}

nonisolated enum DraftGeometryBuilder {
    static func line(id: String, name: String, endpointA: DraftPointChoice?, endpointB: DraftPointChoice?) -> Result<FaceLineSegmentDefinition, DraftGeometryBuilderError> {
        guard let endpointA, let endpointB else { return .failure(.missingPoints) }
        guard endpointA.reference != endpointB.reference else { return .failure(.duplicatePoints) }
        return .success(.init(id: id, displayName: name, endpointA: endpointA.reference, endpointB: endpointB.reference))
    }

    static func polyline(id: String, name: String, points: [DraftPointChoice]) -> Result<FacePolylineDefinition, DraftGeometryBuilderError> {
        guard points.count >= 2 else { return .failure(.missingPoints) }
        return .success(.init(id: id, displayName: name, points: points.map(\.reference)))
    }

    static func plane(id: String, name: String, pointA: DraftPointChoice?, pointB: DraftPointChoice?, pointC: DraftPointChoice?) -> Result<FacePlaneDefinition, DraftGeometryBuilderError> {
        guard let pointA, let pointB, let pointC else { return .failure(.missingPoints) }
        guard Set([pointA.reference, pointB.reference, pointC.reference]).count == 3 else { return .failure(.duplicatePoints) }
        return .success(.init(id: id, displayName: name, pointA: pointA.reference, pointB: pointB.reference, pointC: pointC.reference))
    }
}

nonisolated enum DraftConfigurationDeletionError: Error, Equatable, Sendable {
    case referencedLandmark([String])
}

nonisolated enum DraftConfigurationDeletion {
    static func landmark(id: String, from configuration: ResearchFaceGeometryConfiguration) -> Result<ResearchFaceGeometryConfiguration, DraftConfigurationDeletionError> {
        let dependencies = configuration.lines.filter { $0.endpointA == .landmark(id: id) || $0.endpointB == .landmark(id: id) }.map(\.displayName)
            + configuration.polylines.filter { $0.points.contains(.landmark(id: id)) }.map(\.displayName)
            + configuration.planes.filter { [$0.pointA, $0.pointB, $0.pointC].contains(.landmark(id: id)) }.map(\.displayName)
        guard dependencies.isEmpty else { return .failure(.referencedLandmark(dependencies)) }
        var result = configuration
        result.landmarks.removeAll { $0.id == id }
        return .success(result)
    }
}

nonisolated enum FaceMeshViewPreset: String, CaseIterable, Identifiable, Sendable {
    case front
    case subjectLeft
    case subjectRight

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .front: return "Front"
        case .subjectLeft: return "Subject Left"
        case .subjectRight: return "Subject Right"
        }
    }

    var yawRadians: Float {
        switch self {
        case .front: return 0
        case .subjectLeft: return -.pi / 4
        case .subjectRight: return .pi / 4
        }
    }
}

nonisolated struct FaceMeshViewState: Equatable, Sendable {
    var preset: FaceMeshViewPreset = .front
    mutating func reset() { preset = .front }
}

nonisolated struct FaceMeshRenderSpecification: Equatable, Sendable {
    let vertexPointCount: Int
    let triangleIndexCount: Int
    let trianglePrimitiveCount: Int
    let pointSize: Float
    let minimumPointRadius: Float
    let maximumPointRadius: Float
    let materialOpacity: Float
    let usesConstantLighting: Bool
    let isDoubleSided: Bool

    static func make(frame: RawFaceMeshFrame, topology: FaceMeshTopology) -> FaceMeshRenderSpecification? {
        guard frame.vertices.count == topology.vertexCount,
              topology.triangleIndices.count == topology.triangleCount * 3 else { return nil }
        return FaceMeshRenderSpecification(vertexPointCount: frame.vertices.count,
                                           triangleIndexCount: topology.triangleIndices.count,
                                           trianglePrimitiveCount: topology.triangleCount,
                                           pointSize: 7,
                                           minimumPointRadius: 2.5,
                                           maximumPointRadius: 9,
                                           materialOpacity: 1,
                                           usesConstantLighting: true,
                                           isDoubleSided: true)
    }
}

nonisolated struct ProjectedFaceMeshVertex: Equatable, Sendable {
    let index: Int
    let screenPoint: CGPoint
    let depth: Float
}

nonisolated struct FaceMeshBounds: Equatable, Sendable {
    let minimum: FaceMeshVertex
    let maximum: FaceMeshVertex

    var center: FaceMeshVertex {
        FaceMeshVertex(x: (minimum.x + maximum.x) / 2,
                       y: (minimum.y + maximum.y) / 2,
                       z: (minimum.z + maximum.z) / 2)
    }
    var width: Float { maximum.x - minimum.x }
    var height: Float { maximum.y - minimum.y }
    var depth: Float { maximum.z - minimum.z }
    var largestExtent: Float { max(width, height, depth) }

    static func calculate(vertices: [FaceMeshVertex]) -> FaceMeshBounds? {
        guard let first = vertices.first,
              first.x.isFinite, first.y.isFinite, first.z.isFinite else { return nil }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        var minZ = first.z, maxZ = first.z
        for vertex in vertices.dropFirst() {
            guard vertex.x.isFinite, vertex.y.isFinite, vertex.z.isFinite else { return nil }
            minX = min(minX, vertex.x); maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y); maxY = max(maxY, vertex.y)
            minZ = min(minZ, vertex.z); maxZ = max(maxZ, vertex.z)
        }
        return FaceMeshBounds(minimum: .init(x: minX, y: minY, z: minZ),
                              maximum: .init(x: maxX, y: maxY, z: maxZ))
    }
}

nonisolated struct FaceMeshCameraFraming: Equatable, Sendable {
    let rawBounds: FaceMeshBounds
    let displayCenter: FaceMeshVertex
    let orthographicScale: Float
    let cameraDistance: Float
    let zNear: Float
    let zFar: Float

    static func calculate(
        vertices: [FaceMeshVertex],
        preset: FaceMeshViewPreset,
        viewportAspectRatio: Float,
        padding: Float = 1.18
    ) -> FaceMeshCameraFraming? {
        guard let bounds = FaceMeshBounds.calculate(vertices: vertices), bounds.largestExtent > 0,
              viewportAspectRatio.isFinite, viewportAspectRatio > 0, padding >= 1 else { return nil }
        let center = bounds.center
        let rotation = simd_float3x3(simd_quatf(angle: preset.yawRadians, axis: SIMD3(0, 1, 0)))
        let displayed = vertices.map { rotation * ($0.simdValue - center.simdValue) }
        let displayedVertices = displayed.map(FaceMeshVertex.init)
        guard let displayBounds = FaceMeshBounds.calculate(vertices: displayedVertices) else { return nil }
        let requiredVertical = max(displayBounds.height, displayBounds.width / viewportAspectRatio)
        let scale = max(requiredVertical * padding, Float.leastNonzeroMagnitude)
        let radius = max(displayBounds.largestExtent / 2, Float.leastNonzeroMagnitude)
        let distance = max(radius * 4, 0.001)
        return FaceMeshCameraFraming(rawBounds: bounds, displayCenter: center,
                                     orthographicScale: scale, cameraDistance: distance,
                                     zNear: max(distance - radius * 2, 0.000_001),
                                     zFar: distance + radius * 2)
    }

    func centered(_ vertex: FaceMeshVertex) -> FaceMeshVertex {
        FaceMeshVertex(x: vertex.x - displayCenter.x,
                       y: vertex.y - displayCenter.y,
                       z: vertex.z - displayCenter.z)
    }

    func displayed(_ vertex: FaceMeshVertex, preset: FaceMeshViewPreset) -> FaceMeshVertex {
        let rotation = simd_float3x3(simd_quatf(angle: preset.yawRadians, axis: SIMD3(0, 1, 0)))
        return FaceMeshVertex(rotation * centered(vertex).simdValue)
    }
}

nonisolated enum FaceMeshProjection {
    static func project(
        vertices: [FaceMeshVertex],
        yawRadians: Float,
        pitchRadians: Float = 0,
        scale: CGFloat,
        center: CGPoint
    ) -> [ProjectedFaceMeshVertex] {
        let rotation = simd_float3x3(simd_quatf(angle: yawRadians, axis: SIMD3(0, 1, 0))) *
            simd_float3x3(simd_quatf(angle: pitchRadians, axis: SIMD3(1, 0, 0)))
        return vertices.enumerated().map { index, vertex in
            let displayed = rotation * vertex.simdValue
            return ProjectedFaceMeshVertex(
                index: index,
                screenPoint: CGPoint(x: center.x + CGFloat(displayed.x) * scale,
                                     y: center.y - CGFloat(displayed.y) * scale),
                depth: displayed.z
            )
        }
    }

    static func nearestVertex(
        to point: CGPoint,
        projectedVertices: [ProjectedFaceMeshVertex],
        tolerance: CGFloat
    ) -> Int? {
        projectedVertices.compactMap { vertex -> (Int, CGFloat, Float)? in
            let dx = vertex.screenPoint.x - point.x
            let dy = vertex.screenPoint.y - point.y
            let distanceSquared = dx * dx + dy * dy
            guard distanceSquared <= tolerance * tolerance else { return nil }
            return (vertex.index, distanceSquared, vertex.depth)
        }.min {
            if $0.1 == $1.1 { return $0.2 > $1.2 }
            return $0.1 < $1.1
        }?.0
    }
}

nonisolated enum FaceMeshTopologyInspector {
    static func neighbors(of vertexIndex: Int, topology: FaceMeshTopology) -> [Int] {
        guard (0..<topology.vertexCount).contains(vertexIndex) else { return [] }
        var neighbors = Set<Int>()
        for start in stride(from: 0, to: topology.triangleIndices.count, by: 3) {
            guard start + 2 < topology.triangleIndices.count else { break }
            let triangle = (start...start + 2).map { Int(topology.triangleIndices[$0]) }
            guard triangle.contains(vertexIndex) else { continue }
            neighbors.formUnion(triangle.filter { $0 != vertexIndex })
        }
        return neighbors.sorted()
    }
}

nonisolated struct FaceMeshVertexTrajectorySample: Codable, Equatable, Sendable {
    let sourceTimestamp: TimeInterval
    let taskType: TaskType
    let repetitionIndex: Int
    let frameIndex: Int
    let position: FaceMeshVertex
}

nonisolated struct FaceMeshVertexDisplacement: Equatable, Sendable {
    let dx: Float
    let dy: Float
    let dz: Float
    let euclideanMeters: Float

    var euclideanMillimeters: Float { euclideanMeters * 1_000 }
}

nonisolated enum FaceMeshComparisonError: Error, Equatable, Sendable {
    case topologyMismatch
    case vertexUnavailable(index: Int)
    case comparisonFrameUnavailable
}

nonisolated enum FaceMeshComparison {
    static func position(index: Int, in frame: RawFaceMeshFrame?) -> Result<FaceMeshVertex, FaceMeshComparisonError> {
        guard let frame else { return .failure(.comparisonFrameUnavailable) }
        guard frame.vertices.indices.contains(index) else { return .failure(.vertexUnavailable(index: index)) }
        return .success(frame.vertices[index])
    }

    static func displacement(index: Int, reference: RawFaceMeshFrame?, comparison: RawFaceMeshFrame?) -> Result<FaceMeshVertexDisplacement, FaceMeshComparisonError> {
        guard let reference, let comparison else { return .failure(.comparisonFrameUnavailable) }
        guard reference.topologyID == comparison.topologyID else { return .failure(.topologyMismatch) }
        guard reference.vertices.indices.contains(index), comparison.vertices.indices.contains(index) else {
            return .failure(.vertexUnavailable(index: index))
        }
        let a = reference.vertices[index]
        let b = comparison.vertices[index]
        let delta = b.simdValue - a.simdValue
        return .success(FaceMeshVertexDisplacement(dx: delta.x, dy: delta.y, dz: delta.z,
                                                   euclideanMeters: simd_length(delta)))
    }

    static func trajectory(index: Int, frames: [RawFaceMeshFrame]) -> [FaceMeshVertexTrajectorySample] {
        frames.compactMap { frame in
            guard frame.vertices.indices.contains(index) else { return nil }
            return FaceMeshVertexTrajectorySample(sourceTimestamp: frame.sourceTimestamp,
                                                  taskType: frame.taskType,
                                                  repetitionIndex: frame.repetitionIndex,
                                                  frameIndex: frame.frameIndex,
                                                  position: frame.vertices[index])
        }.sorted { $0.sourceTimestamp < $1.sourceTimestamp }
    }
}
