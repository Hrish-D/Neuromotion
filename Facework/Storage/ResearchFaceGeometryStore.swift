import Foundation

struct StoredFaceMeshSession: Sendable {
    let folderURL: URL
    let metadata: SessionMetadata
    let topology: FaceMeshTopology
    let meshExport: RawFaceMeshFramesExport
    let rawFrames: [RawFrameCapture]
}

enum StoredFaceMeshSessionError: Error, Equatable {
    case meshDataUnavailable
    case inactiveMeshVersion
    case topologyMismatch
    case malformedData(String)
}

struct ResearchFaceGeometryStore {
    static let draftFileName = "research_face_geometry_configuration.json"
    static let candidateFileName = "candidate_face_geometry_configuration.json"
    static let measurementsFileName = "face_geometry_measurements.json"
    static let summaryFileName = "face_geometry_measurement_summary.json"
    static let neutralReferenceFileName = "face_geometry_neutral_reference.json"

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
            let rawURL = folderURL.appendingPathComponent(SessionStore.rawFramesFileName)
            let rawFrames = FileManager.default.fileExists(atPath: rawURL.path)
                ? try decoder.decode([RawFrameCapture].self, from: Data(contentsOf: rawURL)) : []
            guard meshExport.frames.allSatisfy({ $0.topologyID == topology.topologyID && $0.vertices.count == topology.vertexCount }) else {
                throw StoredFaceMeshSessionError.topologyMismatch
            }
            return StoredFaceMeshSession(folderURL: folderURL, metadata: metadata, topology: topology,
                                         meshExport: meshExport, rawFrames: rawFrames)
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

    func exportCandidate(_ candidate: CandidateFaceGeometryConfiguration, for session: StoredFaceMeshSession) throws -> URL {
        let issues = CandidateConfigurationValidator.validate(candidate, topology: session.topology, frame: session.meshExport.frames.first)
        guard issues.isEmpty else { throw ResearchFaceGeometryStoreError.invalidCandidateConfiguration(issues) }
        let url = session.folderURL.appendingPathComponent(Self.candidateFileName)
        try encodedValue(candidate).write(to: url, options: .atomic)
        return url
    }

    func importCandidate(from url: URL, for session: StoredFaceMeshSession) throws -> CandidateFaceGeometryConfiguration {
        let candidate: CandidateFaceGeometryConfiguration = try decodedValue(from: url)
        let issues = CandidateConfigurationValidator.validate(candidate, topology: session.topology, frame: session.meshExport.frames.first)
        guard issues.isEmpty else { throw ResearchFaceGeometryStoreError.invalidCandidateConfiguration(issues) }
        return candidate
    }

    func exportMeasurements(_ package: FaceGeometryMeasurementPackage, for session: StoredFaceMeshSession) throws -> [URL] {
        guard package.sourceSessionID == session.metadata.sessionID, package.topologyID == session.topology.topologyID else {
            throw ResearchFaceGeometryStoreError.measurementProvenanceMismatch
        }
        let measurementsURL = try exportMeasurementRecords(package, for: session)
        let summaryURL = try exportMeasurementSummary(package, for: session)
        let neutralURL = try exportNeutralReference(package.neutralReference, for: session)
        return [measurementsURL, summaryURL, neutralURL]
    }

    func exportNeutralReference(_ reference: FaceGeometryNeutralReference, for session: StoredFaceMeshSession) throws -> URL {
        guard reference.sourceSessionID == session.metadata.sessionID, reference.topologyID == session.topology.topologyID else {
            throw ResearchFaceGeometryStoreError.measurementProvenanceMismatch
        }
        let url = session.folderURL.appendingPathComponent(Self.neutralReferenceFileName)
        try encodedValue(reference).write(to: url, options: .atomic)
        return url
    }

    func exportMeasurementRecords(_ package: FaceGeometryMeasurementPackage, for session: StoredFaceMeshSession) throws -> URL {
        guard package.sourceSessionID == session.metadata.sessionID, package.topologyID == session.topology.topologyID else {
            throw ResearchFaceGeometryStoreError.measurementProvenanceMismatch
        }
        let url = session.folderURL.appendingPathComponent(Self.measurementsFileName)
        try encodedValue(package).write(to: url, options: .atomic)
        return url
    }

    func exportMeasurementSummary(_ package: FaceGeometryMeasurementPackage, for session: StoredFaceMeshSession) throws -> URL {
        guard package.sourceSessionID == session.metadata.sessionID, package.topologyID == session.topology.topologyID else {
            throw ResearchFaceGeometryStoreError.measurementProvenanceMismatch
        }
        let url = session.folderURL.appendingPathComponent(Self.summaryFileName)
        try encodedValue(FaceGeometryMeasurementSummaryExport(
            measurementSchemaVersion: package.measurementSchemaVersion,
            measurementAnalysisAlgorithmVersion: package.measurementAnalysisAlgorithmVersion,
            sourceSessionID: package.sourceSessionID, topologyID: package.topologyID,
            candidateConfigurationID: package.candidateConfigurationID,
            candidateConfigurationHash: package.candidateConfigurationHash,
            neutralReferenceID: package.neutralReference.neutralReferenceID,
            repetitionSummaries: package.repetitionSummaries, taskSummaries: package.taskSummaries
        )).write(to: url, options: .atomic)
        return url
    }

    private func encodedValue<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    private func decodedValue<T: Decodable>(from url: URL) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}

enum ResearchFaceGeometryStoreError: Error, Equatable {
    case invalidConfiguration([ResearchGeometryConfigurationIssue])
    case invalidCandidateConfiguration([CandidateConfigurationIssue])
    case measurementProvenanceMismatch
}

struct FaceGeometryMeasurementSummaryExport: Codable, Equatable, Sendable {
    let measurementSchemaVersion: String
    let measurementAnalysisAlgorithmVersion: String
    let sourceSessionID: String
    let topologyID: String
    let candidateConfigurationID: String
    let candidateConfigurationHash: String
    let neutralReferenceID: String
    let repetitionSummaries: [FaceGeometrySeriesSummary]
    let taskSummaries: [FaceGeometryTaskSummary]
}
