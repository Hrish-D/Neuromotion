import Foundation
import simd

nonisolated enum FaceSubjectSide: String, Codable, CaseIterable, Sendable {
    case subjectLeft
    case subjectRight
    case midline
    case unspecified

    var displayName: String {
        switch self {
        case .subjectLeft: return "Subject Left"
        case .subjectRight: return "Subject Right"
        case .midline: return "Midline"
        case .unspecified: return "Unspecified"
        }
    }
}

nonisolated enum ResearchConfigurationStatus: String, Codable, Sendable {
    case draft
}

nonisolated enum FaceGeometryPointReference: Codable, Equatable, Hashable, Sendable {
    case meshVertex(index: Int)
    case landmark(id: String)
}

nonisolated struct FaceRegionDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let vertexIndices: [Int]
    let side: FaceSubjectSide
    let notes: String?

    init(id: String, displayName: String, vertexIndices: [Int], side: FaceSubjectSide = .unspecified, notes: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.vertexIndices = vertexIndices
        self.side = side
        self.notes = notes
    }
}

nonisolated struct FaceLineSegmentDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let endpointA: FaceGeometryPointReference
    let endpointB: FaceGeometryPointReference
}

nonisolated struct FacePolylineDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let points: [FaceGeometryPointReference]
}

nonisolated struct FacePlaneDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let pointA: FaceGeometryPointReference
    let pointB: FaceGeometryPointReference
    let pointC: FaceGeometryPointReference
}

nonisolated struct ResearchFaceGeometryConfiguration: Codable, Equatable, Identifiable, Sendable {
    let configurationID: String
    var id: String { configurationID }
    let configurationName: String
    let draftRevision: String
    let createdAt: Date
    let requiredTopologyID: String
    let status: ResearchConfigurationStatus
    var landmarks: [FaceLandmarkDefinition]
    var regions: [FaceRegionDefinition]
    var lines: [FaceLineSegmentDefinition]
    var polylines: [FacePolylineDefinition]
    var planes: [FacePlaneDefinition]
    var notes: String?

    static func empty(topologyID: String, name: String = "Untitled Research Draft") -> Self {
        let createdAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        return Self(configurationID: UUID().uuidString, configurationName: name, draftRevision: "draft-1",
             createdAt: createdAt, requiredTopologyID: topologyID, status: .draft,
             landmarks: [], regions: [], lines: [], polylines: [], planes: [], notes: nil)
    }
}

nonisolated enum ResearchGeometryConfigurationIssue: Error, Equatable, Sendable {
    case topologyMismatch
    case duplicateLandmarkID(String)
    case duplicateRegionID(String)
    case duplicateGeometryID(String)
    case duplicateRegionVertex(regionID: String, index: Int)
    case invalidVertexIndex(ownerID: String, index: Int)
    case unresolvedLandmarkReference(ownerID: String, landmarkID: String)
    case duplicateLineEndpoints(String)
    case polylineTooShort(String)
    case planePointsNotDistinct(String)
    case planePointsCollinear(String)

    var message: String {
        switch self {
        case .topologyMismatch: return "Configuration topology does not match this session."
        case .duplicateLandmarkID(let id): return "Duplicate landmark ID: \(id)."
        case .duplicateRegionID(let id): return "Duplicate region ID: \(id)."
        case .duplicateGeometryID(let id): return "Duplicate geometry ID: \(id)."
        case .duplicateRegionVertex(let id, let index): return "Region \(id) repeats vertex \(index)."
        case .invalidVertexIndex(let id, let index): return "\(id) references invalid vertex \(index)."
        case .unresolvedLandmarkReference(let id, let landmark): return "\(id) references unknown landmark \(landmark)."
        case .duplicateLineEndpoints(let id): return "Line \(id) must use two distinct points."
        case .polylineTooShort(let id): return "Polyline \(id) requires at least two points."
        case .planePointsNotDistinct(let id): return "Plane \(id) requires three distinct points."
        case .planePointsCollinear(let id): return "Plane \(id) points are collinear."
        }
    }
}

nonisolated enum ResearchFaceGeometryValidator {
    static func validate(
        _ configuration: ResearchFaceGeometryConfiguration,
        topology: FaceMeshTopology,
        frame: RawFaceMeshFrame? = nil,
        collinearityEpsilon: Float = 1e-10
    ) -> [ResearchGeometryConfigurationIssue] {
        var issues: [ResearchGeometryConfigurationIssue] = []
        if configuration.requiredTopologyID != topology.topologyID { issues.append(.topologyMismatch) }

        let landmarkGroups = Dictionary(grouping: configuration.landmarks, by: \.id)
        for id in landmarkGroups.keys where landmarkGroups[id, default: []].count > 1 { issues.append(.duplicateLandmarkID(id)) }
        let landmarkByID = Dictionary(uniqueKeysWithValues: landmarkGroups.compactMap { key, values in values.first.map { (key, $0) } })
        for landmark in configuration.landmarks { validate(landmark.source, ownerID: landmark.id, topology: topology, issues: &issues) }

        let regionGroups = Dictionary(grouping: configuration.regions, by: \.id)
        for id in regionGroups.keys where regionGroups[id, default: []].count > 1 { issues.append(.duplicateRegionID(id)) }
        for region in configuration.regions {
            var seen = Set<Int>()
            for index in region.vertexIndices {
                if !seen.insert(index).inserted { issues.append(.duplicateRegionVertex(regionID: region.id, index: index)) }
                validate(index: index, ownerID: region.id, topology: topology, issues: &issues)
            }
        }

        let allGeometryIDs = configuration.lines.map(\.id) + configuration.polylines.map(\.id) + configuration.planes.map(\.id)
        for (id, count) in Dictionary(grouping: allGeometryIDs, by: { $0 }).mapValues(\.count) where count > 1 {
            issues.append(.duplicateGeometryID(id))
        }
        for line in configuration.lines {
            validate(line.endpointA, ownerID: line.id, topology: topology, landmarkByID: landmarkByID, issues: &issues)
            validate(line.endpointB, ownerID: line.id, topology: topology, landmarkByID: landmarkByID, issues: &issues)
            if line.endpointA == line.endpointB { issues.append(.duplicateLineEndpoints(line.id)) }
        }
        for polyline in configuration.polylines {
            if polyline.points.count < 2 { issues.append(.polylineTooShort(polyline.id)) }
            for point in polyline.points { validate(point, ownerID: polyline.id, topology: topology, landmarkByID: landmarkByID, issues: &issues) }
        }
        for plane in configuration.planes {
            let refs = [plane.pointA, plane.pointB, plane.pointC]
            for point in refs { validate(point, ownerID: plane.id, topology: topology, landmarkByID: landmarkByID, issues: &issues) }
            if Set(refs).count != 3 { issues.append(.planePointsNotDistinct(plane.id)); continue }
            if let frame,
               let a = resolve(refs[0], frame: frame, landmarks: landmarkByID),
               let b = resolve(refs[1], frame: frame, landmarks: landmarkByID),
               let c = resolve(refs[2], frame: frame, landmarks: landmarkByID),
               simd_length_squared(simd_cross(b.simdValue - a.simdValue, c.simdValue - a.simdValue)) <= collinearityEpsilon {
                issues.append(.planePointsCollinear(plane.id))
            }
        }
        return issues
    }

    private static func validate(_ source: FaceLandmarkSource, ownerID: String, topology: FaceMeshTopology, issues: inout [ResearchGeometryConfigurationIssue]) {
        if case .meshVertex(let index) = source { validate(index: index, ownerID: ownerID, topology: topology, issues: &issues) }
    }

    private static func validate(index: Int, ownerID: String, topology: FaceMeshTopology, issues: inout [ResearchGeometryConfigurationIssue]) {
        if !(0..<topology.vertexCount).contains(index) { issues.append(.invalidVertexIndex(ownerID: ownerID, index: index)) }
    }

    private static func validate(_ reference: FaceGeometryPointReference, ownerID: String, topology: FaceMeshTopology, landmarkByID: [String: FaceLandmarkDefinition], issues: inout [ResearchGeometryConfigurationIssue]) {
        switch reference {
        case .meshVertex(let index): validate(index: index, ownerID: ownerID, topology: topology, issues: &issues)
        case .landmark(let id):
            if landmarkByID[id] == nil { issues.append(.unresolvedLandmarkReference(ownerID: ownerID, landmarkID: id)) }
        }
    }

    private static func resolve(_ reference: FaceGeometryPointReference, frame: RawFaceMeshFrame, landmarks: [String: FaceLandmarkDefinition]) -> FaceMeshVertex? {
        let index: Int
        switch reference {
        case .meshVertex(let value): index = value
        case .landmark(let id):
            guard case .meshVertex(let value)? = landmarks[id]?.source else { return nil }
            index = value
        }
        return frame.vertices.indices.contains(index) ? frame.vertices[index] : nil
    }
}
