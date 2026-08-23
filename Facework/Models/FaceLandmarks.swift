import Foundation

nonisolated enum FaceLandmarkSource: Codable, Equatable, Sendable {
    case meshVertex(index: Int)
}

nonisolated struct FaceLandmarkDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let source: FaceLandmarkSource
    let side: FaceSubjectSide
    let category: String?
    let notes: String?

    init(
        id: String,
        displayName: String,
        source: FaceLandmarkSource,
        side: FaceSubjectSide = .unspecified,
        category: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.source = source
        self.side = side
        self.category = category
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, source, side, category, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        source = try container.decode(FaceLandmarkSource.self, forKey: .source)
        side = try container.decodeIfPresent(FaceSubjectSide.self, forKey: .side) ?? .unspecified
        category = try container.decodeIfPresent(String.self, forKey: .category)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

nonisolated struct FaceLandmarkConfiguration: Codable, Equatable, Sendable {
    let configurationID: String
    let configurationVersion: String
    let requiredTopologyID: String
    let definitions: [FaceLandmarkDefinition]
}

nonisolated enum FaceLandmarkConfigurationIssue: Equatable, Sendable {
    case topologyMismatch
    case duplicateLandmarkID(String)
    case invalidVertexIndex(landmarkID: String, index: Int)
}

nonisolated struct ExtractedFaceLandmark: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let position: FaceMeshVertex
}

nonisolated enum FaceLandmarkExtractor {
    static func validate(
        configuration: FaceLandmarkConfiguration,
        topology: FaceMeshTopology
    ) -> [FaceLandmarkConfigurationIssue] {
        var issues: [FaceLandmarkConfigurationIssue] = []
        if configuration.requiredTopologyID != topology.topologyID {
            issues.append(.topologyMismatch)
        }
        var ids = Set<String>()
        for definition in configuration.definitions {
            if !ids.insert(definition.id).inserted {
                issues.append(.duplicateLandmarkID(definition.id))
            }
            switch definition.source {
            case .meshVertex(let index):
                if index < 0 || index >= topology.vertexCount {
                    issues.append(.invalidVertexIndex(landmarkID: definition.id, index: index))
                }
            }
        }
        return issues
    }

    static func extract(
        frame: RawFaceMeshFrame,
        topology: FaceMeshTopology,
        configuration: FaceLandmarkConfiguration
    ) -> Result<[ExtractedFaceLandmark], FaceLandmarkExtractionError> {
        guard frame.topologyID == topology.topologyID,
              configuration.requiredTopologyID == topology.topologyID else {
            return .failure(.topologyMismatch)
        }
        let issues = validate(configuration: configuration, topology: topology)
        guard issues.isEmpty else { return .failure(.invalidConfiguration(issues)) }
        guard frame.vertices.count == topology.vertexCount else {
            return .failure(.vertexCountMismatch)
        }
        return .success(configuration.definitions.map { definition in
            switch definition.source {
            case .meshVertex(let index):
                return ExtractedFaceLandmark(
                    id: definition.id,
                    displayName: definition.displayName,
                    position: frame.vertices[index]
                )
            }
        })
    }
}

nonisolated enum FaceLandmarkExtractionError: Error, Equatable {
    case topologyMismatch
    case vertexCountMismatch
    case invalidConfiguration([FaceLandmarkConfigurationIssue])
}
