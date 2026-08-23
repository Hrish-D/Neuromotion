import Foundation

struct StoredFaceMeshSession: Sendable {
    let folderURL: URL
    let metadata: SessionMetadata
    let topology: FaceMeshTopology
    let meshExport: RawFaceMeshFramesExport
}

enum StoredFaceMeshSessionError: Error, Equatable {
    case meshDataUnavailable
    case inactiveMeshVersion
    case topologyMismatch
    case malformedData(String)
}

struct ResearchFaceGeometryStore {
    static let draftFileName = "research_face_geometry_configuration.json"

    func loadSession(at folderURL: URL) throws -> StoredFaceMeshSession {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let metadata = try decoder.decode(SessionMetadata.self, from: Data(contentsOf: folderURL.appendingPathComponent("metadata.json")))
            guard metadata.meshCaptureVersion != "not-active" else { throw StoredFaceMeshSessionError.inactiveMeshVersion }
            let topologyURL = folderURL.appendingPathComponent(SessionStore.faceMeshTopologyFileName)
            let framesURL = folderURL.appendingPathComponent(SessionStore.rawFaceMeshFramesFileName)
            guard FileManager.default.fileExists(atPath: topologyURL.path), FileManager.default.fileExists(atPath: framesURL.path) else {
                throw StoredFaceMeshSessionError.meshDataUnavailable
            }
            let topology = try decoder.decode(FaceMeshTopology.self, from: Data(contentsOf: topologyURL))
            let meshExport = try decoder.decode(RawFaceMeshFramesExport.self, from: Data(contentsOf: framesURL))
            guard meshExport.frames.allSatisfy({ $0.topologyID == topology.topologyID && $0.vertices.count == topology.vertexCount }) else {
                throw StoredFaceMeshSessionError.topologyMismatch
            }
            return StoredFaceMeshSession(folderURL: folderURL, metadata: metadata, topology: topology, meshExport: meshExport)
        } catch let error as StoredFaceMeshSessionError {
            throw error
        } catch {
            throw StoredFaceMeshSessionError.malformedData(error.localizedDescription)
        }
    }

    @discardableResult
    func exportDraft(_ configuration: ResearchFaceGeometryConfiguration, for session: StoredFaceMeshSession) throws -> URL {
        let issues = ResearchFaceGeometryValidator.validate(configuration, topology: session.topology, frame: session.meshExport.frames.first)
        guard issues.isEmpty else { throw ResearchFaceGeometryStoreError.invalidConfiguration(issues) }
        let url = session.folderURL.appendingPathComponent(Self.draftFileName)
        try encoded(configuration).write(to: url, options: .atomic)
        return url
    }

    func importDraft(from url: URL, for session: StoredFaceMeshSession) throws -> ResearchFaceGeometryConfiguration {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let configuration = try decoder.decode(ResearchFaceGeometryConfiguration.self, from: Data(contentsOf: url))
        let issues = ResearchFaceGeometryValidator.validate(configuration, topology: session.topology, frame: session.meshExport.frames.first)
        guard issues.isEmpty else { throw ResearchFaceGeometryStoreError.invalidConfiguration(issues) }
        return configuration
    }

    func encoded(_ configuration: ResearchFaceGeometryConfiguration) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(configuration)
    }
}

enum ResearchFaceGeometryStoreError: Error, Equatable {
    case invalidConfiguration([ResearchGeometryConfigurationIssue])
}
