import CryptoKit
import Foundation

nonisolated enum CandidateConfigurationStatus: String, Codable, Sendable {
    case candidateForReview
}

nonisolated enum Prompt13PairWorkspaceError: Error, Equatable, Sendable {
    case invalid([CandidateConfigurationIssue])
}

nonisolated enum Prompt13PairWorkspace {
    static func addingLandmarkPair(
        _ pair: BilateralLandmarkPair, to existing: [BilateralLandmarkPair], regionPairs: [BilateralRegionPair],
        draft: ResearchFaceGeometryConfiguration, topology: FaceMeshTopology, frame: RawFaceMeshFrame?
    ) -> Result<[BilateralLandmarkPair], Prompt13PairWorkspaceError> {
        let proposed = existing + [pair]
        let candidate = CandidateFaceGeometryConfiguration.freeze(
            draft: draft, configurationID: "workspace", createdAt: Date(timeIntervalSince1970: 0),
            bilateralLandmarkPairs: proposed, bilateralRegionPairs: regionPairs
        )
        let issues = CandidateConfigurationValidator.validate(candidate, topology: topology, frame: frame)
        return issues.isEmpty ? .success(proposed) : .failure(.invalid(issues))
    }

    static func addingRegionPair(
        _ pair: BilateralRegionPair, to existing: [BilateralRegionPair], landmarkPairs: [BilateralLandmarkPair],
        draft: ResearchFaceGeometryConfiguration, topology: FaceMeshTopology, frame: RawFaceMeshFrame?
    ) -> Result<[BilateralRegionPair], Prompt13PairWorkspaceError> {
        let proposed = existing + [pair]
        let candidate = CandidateFaceGeometryConfiguration.freeze(
            draft: draft, configurationID: "workspace", createdAt: Date(timeIntervalSince1970: 0),
            bilateralLandmarkPairs: landmarkPairs, bilateralRegionPairs: proposed
        )
        let issues = CandidateConfigurationValidator.validate(candidate, topology: topology, frame: frame)
        return issues.isEmpty ? .success(proposed) : .failure(.invalid(issues))
    }
}

nonisolated struct BilateralLandmarkPair: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let subjectLeftLandmarkID: String
    let subjectRightLandmarkID: String
    let notes: String?
}

nonisolated struct BilateralRegionPair: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let subjectLeftRegionID: String
    let subjectRightRegionID: String
    let notes: String?
}

nonisolated struct CandidateFaceGeometryConfiguration: Codable, Equatable, Identifiable, Sendable {
    let configurationID: String
    var id: String { configurationID }
    let configurationVersion: String
    let configurationName: String
    let createdAt: Date
    let requiredTopologyID: String
    let sourceDraftConfigurationID: String
    let sourceDraftRevision: String
    let status: CandidateConfigurationStatus
    let researchUseOnly: Bool
    let clinicallyValidated: Bool
    let landmarks: [FaceLandmarkDefinition]
    let regions: [FaceRegionDefinition]
    let lines: [FaceLineSegmentDefinition]
    let polylines: [FacePolylineDefinition]
    let planes: [FacePlaneDefinition]
    let bilateralLandmarkPairs: [BilateralLandmarkPair]
    let bilateralRegionPairs: [BilateralRegionPair]
    let scaleReferenceLineID: String?
    let notes: String?
    let configurationHash: String

    private enum CodingKeys: String, CodingKey {
        case configurationID, configurationVersion, configurationName, createdAt, requiredTopologyID
        case sourceDraftConfigurationID, sourceDraftRevision, status, researchUseOnly, clinicallyValidated
        case landmarks, regions, lines, polylines, planes, bilateralLandmarkPairs, bilateralRegionPairs
        case scaleReferenceLineID, notes, configurationHash
    }

    static func freeze(
        draft: ResearchFaceGeometryConfiguration,
        configurationID: String = UUID().uuidString,
        configurationVersion: String = "candidate-1",
        createdAt: Date = Date(),
        bilateralLandmarkPairs: [BilateralLandmarkPair],
        bilateralRegionPairs: [BilateralRegionPair],
        scaleReferenceLineID: String? = nil
    ) -> CandidateFaceGeometryConfiguration {
        let hash = CandidateConfigurationHasher.hash(
            configurationVersion: configurationVersion, requiredTopologyID: draft.requiredTopologyID,
            landmarks: draft.landmarks, regions: draft.regions, lines: draft.lines,
            polylines: draft.polylines, planes: draft.planes,
            bilateralLandmarkPairs: bilateralLandmarkPairs, bilateralRegionPairs: bilateralRegionPairs,
            scaleReferenceLineID: scaleReferenceLineID
        )
        return CandidateFaceGeometryConfiguration(
            configurationID: configurationID, configurationVersion: configurationVersion,
            configurationName: draft.configurationName, createdAt: createdAt,
            requiredTopologyID: draft.requiredTopologyID,
            sourceDraftConfigurationID: draft.configurationID, sourceDraftRevision: draft.draftRevision,
            status: .candidateForReview, researchUseOnly: true, clinicallyValidated: false,
            landmarks: draft.landmarks, regions: draft.regions, lines: draft.lines,
            polylines: draft.polylines, planes: draft.planes,
            bilateralLandmarkPairs: bilateralLandmarkPairs, bilateralRegionPairs: bilateralRegionPairs,
            scaleReferenceLineID: scaleReferenceLineID, notes: draft.notes, configurationHash: hash
        )
    }
}

nonisolated enum CandidateConfigurationIssue: Error, Equatable, Sendable {
    case draftIssue(ResearchGeometryConfigurationIssue)
    case duplicateBilateralPairID(String)
    case missingLandmark(pairID: String, landmarkID: String)
    case sameLandmark(pairID: String)
    case wrongLandmarkSide(pairID: String)
    case missingRegion(pairID: String, regionID: String)
    case sameRegion(pairID: String)
    case wrongRegionSide(pairID: String)
    case invalidScaleReference(String)
    case hashMismatch
}

nonisolated enum CandidateConfigurationValidator {
    static func validate(_ candidate: CandidateFaceGeometryConfiguration, topology: FaceMeshTopology, frame: RawFaceMeshFrame? = nil) -> [CandidateConfigurationIssue] {
        var issues = draftIssues(candidate, topology: topology, frame: frame)
        let landmarks = Dictionary(grouping: candidate.landmarks, by: \.id).compactMapValues(\.first)
        let regions = Dictionary(grouping: candidate.regions, by: \.id).compactMapValues(\.first)
        let pairIDs = candidate.bilateralLandmarkPairs.map(\.id) + candidate.bilateralRegionPairs.map(\.id)
        for (id, values) in Dictionary(grouping: pairIDs, by: { $0 }) where values.count > 1 { issues.append(.duplicateBilateralPairID(id)) }
        for pair in candidate.bilateralLandmarkPairs {
            guard pair.subjectLeftLandmarkID != pair.subjectRightLandmarkID else { issues.append(.sameLandmark(pairID: pair.id)); continue }
            guard let left = landmarks[pair.subjectLeftLandmarkID] else { issues.append(.missingLandmark(pairID: pair.id, landmarkID: pair.subjectLeftLandmarkID)); continue }
            guard let right = landmarks[pair.subjectRightLandmarkID] else { issues.append(.missingLandmark(pairID: pair.id, landmarkID: pair.subjectRightLandmarkID)); continue }
            if left.side != .subjectLeft || right.side != .subjectRight { issues.append(.wrongLandmarkSide(pairID: pair.id)) }
        }
        for pair in candidate.bilateralRegionPairs {
            guard pair.subjectLeftRegionID != pair.subjectRightRegionID else { issues.append(.sameRegion(pairID: pair.id)); continue }
            guard let left = regions[pair.subjectLeftRegionID] else { issues.append(.missingRegion(pairID: pair.id, regionID: pair.subjectLeftRegionID)); continue }
            guard let right = regions[pair.subjectRightRegionID] else { issues.append(.missingRegion(pairID: pair.id, regionID: pair.subjectRightRegionID)); continue }
            if left.side != .subjectLeft || right.side != .subjectRight { issues.append(.wrongRegionSide(pairID: pair.id)) }
        }
        if let lineID = candidate.scaleReferenceLineID, !candidate.lines.contains(where: { $0.id == lineID }) {
            issues.append(.invalidScaleReference(lineID))
        }
        let expected = CandidateConfigurationHasher.hash(candidate)
        if expected != candidate.configurationHash { issues.append(.hashMismatch) }
        return issues
    }

    private static func draftIssues(_ candidate: CandidateFaceGeometryConfiguration, topology: FaceMeshTopology, frame: RawFaceMeshFrame?) -> [CandidateConfigurationIssue] {
        let draft = ResearchFaceGeometryConfiguration(
            configurationID: candidate.sourceDraftConfigurationID, configurationName: candidate.configurationName,
            draftRevision: candidate.sourceDraftRevision, createdAt: candidate.createdAt,
            requiredTopologyID: candidate.requiredTopologyID, status: .draft,
            landmarks: candidate.landmarks, regions: candidate.regions, lines: candidate.lines,
            polylines: candidate.polylines, planes: candidate.planes, notes: candidate.notes
        )
        return ResearchFaceGeometryValidator.validate(draft, topology: topology, frame: frame).map(CandidateConfigurationIssue.draftIssue)
    }
}

nonisolated enum CandidateConfigurationHasher {
    static func hash(_ candidate: CandidateFaceGeometryConfiguration) -> String {
        hash(configurationVersion: candidate.configurationVersion, requiredTopologyID: candidate.requiredTopologyID,
             landmarks: candidate.landmarks, regions: candidate.regions, lines: candidate.lines,
             polylines: candidate.polylines, planes: candidate.planes,
             bilateralLandmarkPairs: candidate.bilateralLandmarkPairs, bilateralRegionPairs: candidate.bilateralRegionPairs,
             scaleReferenceLineID: candidate.scaleReferenceLineID)
    }

    static func hash(configurationVersion: String, requiredTopologyID: String,
                     landmarks: [FaceLandmarkDefinition], regions: [FaceRegionDefinition],
                     lines: [FaceLineSegmentDefinition], polylines: [FacePolylineDefinition], planes: [FacePlaneDefinition],
                     bilateralLandmarkPairs: [BilateralLandmarkPair], bilateralRegionPairs: [BilateralRegionPair],
                     scaleReferenceLineID: String?) -> String {
        var fields = ["facework-candidate-geometry-v1", configurationVersion, requiredTopologyID]
        // Names and notes are intentionally excluded: they are display metadata, not measurement semantics.
        fields += landmarks.sorted { $0.id < $1.id }.map { "L|\($0.id)|\(source($0.source))|\($0.side.rawValue)" }
        fields += regions.sorted { $0.id < $1.id }.map { "R|\($0.id)|\($0.vertexIndices.map(String.init).joined(separator: ","))|\($0.side.rawValue)" }
        fields += lines.sorted { $0.id < $1.id }.map { "S|\($0.id)|\(reference($0.endpointA))|\(reference($0.endpointB))" }
        fields += polylines.sorted { $0.id < $1.id }.map { "P|\($0.id)|\($0.points.map(reference).joined(separator: ","))" }
        fields += planes.sorted { $0.id < $1.id }.map { "N|\($0.id)|\(reference($0.pointA))|\(reference($0.pointB))|\(reference($0.pointC))" }
        fields += bilateralLandmarkPairs.sorted { $0.id < $1.id }.map { "BL|\($0.id)|\($0.subjectLeftLandmarkID)|\($0.subjectRightLandmarkID)" }
        fields += bilateralRegionPairs.sorted { $0.id < $1.id }.map { "BR|\($0.id)|\($0.subjectLeftRegionID)|\($0.subjectRightRegionID)" }
        fields.append("SCALE|\(scaleReferenceLineID ?? "")")
        let digest = SHA256.hash(data: Data(fields.joined(separator: "\n").utf8))
        return "facework-candidate-sha256-v1:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func source(_ source: FaceLandmarkSource) -> String {
        if case .meshVertex(let index) = source { return "v:\(index)" }
        return "unknown"
    }
    private static func reference(_ reference: FaceGeometryPointReference) -> String {
        switch reference { case .meshVertex(let index): return "v:\(index)"; case .landmark(let id): return "l:\(id)" }
    }
}
