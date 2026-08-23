import Foundation
import Combine

final class FaceMeshInspectorViewModel: ObservableObject {
    @Published private(set) var session: StoredFaceMeshSession?
    @Published var selectedTask: TaskType = .neutralRest
    @Published var selectedRepetition = 1
    @Published var selectedFrameIndex = 0
    @Published var selectedVertexIndex: Int?
    @Published var referenceFrameID: UUID?
    @Published var regionSelection = Set<Int>()
    @Published var draft: ResearchFaceGeometryConfiguration?
    @Published var message: String?
    @Published var exportedDraftURL: URL?
    @Published var lineEndpointA: DraftPointChoice?
    @Published var lineEndpointB: DraftPointChoice?
    @Published var polylinePoints: [DraftPointChoice] = []
    @Published var planePointA: DraftPointChoice?
    @Published var planePointB: DraftPointChoice?
    @Published var planePointC: DraftPointChoice?
    @Published var selectedSavedRegionID: String?
    @Published var showDraftGeometry = true
    @Published var geometryVertexChoices = Set<Int>()

    private let folderURL: URL
    private let store = ResearchFaceGeometryStore()

    init(folderURL: URL) {
        self.folderURL = folderURL
        load()
    }

    init(session: StoredFaceMeshSession) {
        self.folderURL = session.folderURL
        configure(with: session)
    }

    var topology: FaceMeshTopology? { session?.topology }
    var allFrames: [RawFaceMeshFrame] { session?.meshExport.frames ?? [] }
    var availableTasks: [TaskType] {
        TaskType.allCases.filter { task in allFrames.contains { $0.taskType == task } }
    }
    var availableRepetitions: [Int] {
        Array(Set(allFrames.filter { $0.taskType == selectedTask }.map(\.repetitionIndex))).sorted()
    }
    var availableFrames: [RawFaceMeshFrame] {
        allFrames.filter { $0.taskType == selectedTask && $0.repetitionIndex == selectedRepetition }
            .sorted { $0.frameIndex < $1.frameIndex }
    }
    var selectedFrame: RawFaceMeshFrame? {
        availableFrames.first { $0.frameIndex == selectedFrameIndex } ?? availableFrames.first
    }
    var referenceCandidates: [RawFaceMeshFrame] {
        allFrames.filter { $0.taskType == .neutralRest }.sorted { $0.sourceTimestamp < $1.sourceTimestamp }
    }
    var referenceFrame: RawFaceMeshFrame? {
        referenceCandidates.first { $0.id == referenceFrameID }
    }
    var selectedVertex: FaceMeshVertex? {
        guard let selectedVertexIndex, let selectedFrame, selectedFrame.vertices.indices.contains(selectedVertexIndex) else { return nil }
        return selectedFrame.vertices[selectedVertexIndex]
    }
    var selectedNeighbors: [Int] {
        guard let selectedVertexIndex, let topology else { return [] }
        return FaceMeshTopologyInspector.neighbors(of: selectedVertexIndex, topology: topology)
    }
    var displacement: FaceMeshVertexDisplacement? {
        guard let selectedVertexIndex else { return nil }
        return try? FaceMeshComparison.displacement(index: selectedVertexIndex, reference: referenceFrame, comparison: selectedFrame).get()
    }
    var trajectory: [FaceMeshVertexTrajectorySample] {
        guard let selectedVertexIndex else { return [] }
        return FaceMeshComparison.trajectory(index: selectedVertexIndex, frames: availableFrames)
    }
    var pointChoices: [DraftPointChoice] {
        let landmarks = (draft?.landmarks ?? []).compactMap { landmark -> DraftPointChoice? in
            guard case .meshVertex(let index) = landmark.source else { return nil }
            return .landmark(id: landmark.id, displayName: landmark.displayName, vertexIndex: index)
        }
        let landmarkIndices = Set(landmarks.map(\.vertexIndex))
        var rawIndices = regionSelection
        if let selectedVertexIndex { rawIndices.insert(selectedVertexIndex) }
        rawIndices.formUnion(geometryVertexChoices)
        if let draft {
            let references = draft.lines.flatMap { [$0.endpointA, $0.endpointB] }
                + draft.polylines.flatMap(\.points)
                + draft.planes.flatMap { [$0.pointA, $0.pointB, $0.pointC] }
            for case .meshVertex(let index) in references { rawIndices.insert(index) }
        }
        return landmarks + rawIndices.subtracting(landmarkIndices).sorted().map(DraftPointChoice.meshVertex)
    }
    var overlayConfiguration: ResearchFaceGeometryConfiguration? { showDraftGeometry ? draft : nil }
    var highlightedRegionVertices: Set<Int> {
        var result = regionSelection
        if let id = selectedSavedRegionID, let region = draft?.regions.first(where: { $0.id == id }) {
            result.formUnion(region.vertexIndices)
        }
        return result
    }
    var selectedLandmarks: [FaceLandmarkDefinition] {
        guard let selectedVertexIndex else { return [] }
        return (draft?.landmarks ?? []).filter {
            if case .meshVertex(let value) = $0.source { return value == selectedVertexIndex }
            return false
        }
    }
    var selectedSavedRegions: [FaceRegionDefinition] {
        guard let selectedVertexIndex else { return [] }
        return (draft?.regions ?? []).filter { $0.vertexIndices.contains(selectedVertexIndex) }
    }
    var selectedGeometryNames: [String] {
        guard let index = selectedVertexIndex, let draft else { return [] }
        func resolves(_ reference: FaceGeometryPointReference) -> Bool {
            switch reference {
            case .meshVertex(let value): return value == index
            case .landmark(let id): return draft.landmarks.contains { $0.id == id && $0.source == .meshVertex(index: index) }
            }
        }
        return draft.lines.filter { resolves($0.endpointA) || resolves($0.endpointB) }.map(\.displayName)
            + draft.polylines.filter { $0.points.contains(where: resolves) }.map(\.displayName)
            + draft.planes.filter { [$0.pointA, $0.pointB, $0.pointC].contains(where: resolves) }.map(\.displayName)
    }

    func load() {
        do {
            let loaded = try store.loadSession(at: folderURL)
            configure(with: loaded)
        } catch {
            message = "Mesh data unavailable for this session: \(error)"
        }
    }

    private func configure(with loaded: StoredFaceMeshSession) {
        session = loaded
        selectedTask = loaded.meshExport.frames.contains { $0.taskType == .neutralRest } ? .neutralRest : (loaded.meshExport.frames.first?.taskType ?? .neutralRest)
        selectedRepetition = availableRepetitions.first ?? 1
        selectedFrameIndex = availableFrames.first?.frameIndex ?? 0
        referenceFrameID = referenceCandidates.first?.id
        draft = .empty(topologyID: loaded.topology.topologyID)
    }

    func selectTask(_ task: TaskType) {
        selectedTask = task
        selectedRepetition = availableRepetitions.first ?? 1
        selectedFrameIndex = availableFrames.first?.frameIndex ?? 0
    }

    func selectRepetition(_ repetition: Int) {
        selectedRepetition = repetition
        selectedFrameIndex = availableFrames.first?.frameIndex ?? 0
    }

    func search(indexText: String) {
        guard let topology, let index = Int(indexText), (0..<topology.vertexCount).contains(index) else {
            message = topology.map { "Vertex index must be in 0..<\($0.vertexCount)." } ?? "Topology unavailable."
            return
        }
        selectedVertexIndex = index
        message = nil
    }

    func toggleRegionVertex() {
        guard let selectedVertexIndex else { return }
        if !regionSelection.insert(selectedVertexIndex).inserted { regionSelection.remove(selectedVertexIndex) }
    }

    func clearRegionSelection() { regionSelection.removeAll() }
    func addCurrentVertexToGeometryChoices() {
        guard let selectedVertexIndex else { message = "Select a mesh vertex first."; return }
        geometryVertexChoices.insert(selectedVertexIndex)
        message = nil
    }

    func addLandmark(name: String, side: FaceSubjectSide, category: String?, notes: String?) {
        guard let index = selectedVertexIndex, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = "Select a vertex and enter a research label."
            return
        }
        mutateDraft { draft in
            draft.landmarks.append(FaceLandmarkDefinition(id: UUID().uuidString, displayName: name,
                                                          source: .meshVertex(index: index), side: side,
                                                          category: category.nilIfBlank, notes: notes.nilIfBlank))
        }
    }

    func addRegion(name: String, side: FaceSubjectSide, notes: String?) {
        guard !regionSelection.isEmpty, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = "Select one or more vertices and enter a region name."
            return
        }
        if mutateDraft({ draft in
            draft.regions.append(FaceRegionDefinition(id: UUID().uuidString, displayName: name,
                                                      vertexIndices: regionSelection.sorted(), side: side,
                                                      notes: notes.nilIfBlank))
        }) { regionSelection.removeAll() }
    }

    func addLine(name: String) {
        let result = DraftGeometryBuilder.line(id: UUID().uuidString, name: normalizedName(name, fallback: "Draft Line"),
                                               endpointA: lineEndpointA, endpointB: lineEndpointB)
        guard case .success(let line) = result else {
            if case .failure(.duplicatePoints) = result { message = "Line endpoints must be distinct." } else { message = "Choose both line endpoints." }
            return
        }
        if mutateDraft({ $0.lines.append(line) }) {
            lineEndpointA = nil; lineEndpointB = nil
        }
    }

    func addCurrentVertexToPolyline() {
        guard let selectedVertexIndex else { message = "Select a mesh vertex first."; return }
        geometryVertexChoices.insert(selectedVertexIndex)
        polylinePoints.append(.meshVertex(index: selectedVertexIndex))
    }
    func addPolylinePoint(_ choice: DraftPointChoice) { polylinePoints.append(choice) }
    func removePolylinePoint(at index: Int) { guard polylinePoints.indices.contains(index) else { return }; polylinePoints.remove(at: index) }
    func movePolylinePoint(from index: Int, by offset: Int) {
        let destination = index + offset
        guard polylinePoints.indices.contains(index), polylinePoints.indices.contains(destination) else { return }
        polylinePoints.swapAt(index, destination)
    }
    func clearPolylineBuilder() { polylinePoints.removeAll() }
    func addPolyline(name: String) {
        let result = DraftGeometryBuilder.polyline(id: UUID().uuidString, name: normalizedName(name, fallback: "Draft Polyline"), points: polylinePoints)
        guard case .success(let path) = result else { message = "Polyline requires at least two explicitly ordered points."; return }
        if mutateDraft({ $0.polylines.append(path) }) {
            polylinePoints.removeAll()
        }
    }

    func addPlane(name: String) {
        let result = DraftGeometryBuilder.plane(id: UUID().uuidString, name: normalizedName(name, fallback: "Draft Plane"),
                                                pointA: planePointA, pointB: planePointB, pointC: planePointC)
        guard case .success(let plane) = result else {
            if case .failure(.duplicatePoints) = result { message = "Plane points must be distinct." } else { message = "Choose plane points A, B, and C." }
            return
        }
        if mutateDraft({ $0.planes.append(plane) }) {
            planePointA = nil; planePointB = nil; planePointC = nil
        }
    }

    func deleteLandmark(id: String) {
        guard let draft else { return }
        switch DraftConfigurationDeletion.landmark(id: id, from: draft) {
        case .success(let candidate):
            _ = mutateDraft { $0 = candidate }
        case .failure(.referencedLandmark(let dependencies)):
            message = "Remove dependent geometry first: \(dependencies.joined(separator: ", "))."
        }
    }
    func deleteRegion(id: String) { _ = mutateDraft { $0.regions.removeAll { $0.id == id } }; if selectedSavedRegionID == id { selectedSavedRegionID = nil } }
    func deleteLine(id: String) { _ = mutateDraft { $0.lines.removeAll { $0.id == id } } }
    func deletePolyline(id: String) { _ = mutateDraft { $0.polylines.removeAll { $0.id == id } } }
    func deletePlane(id: String) { _ = mutateDraft { $0.planes.removeAll { $0.id == id } } }

    func exportDraft() {
        guard let session, let draft else { return }
        do {
            exportedDraftURL = try store.exportDraft(draft, for: session)
            message = "Draft configuration exported."
        } catch { message = "Draft export failed: \(error)" }
    }

    func importDraft(from url: URL) {
        guard let session else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            draft = try store.importDraft(from: url, for: session)
            message = "Matching-topology draft imported."
        } catch { message = "Draft import rejected: \(error)" }
    }

    @discardableResult private func mutateDraft(_ mutation: (inout ResearchFaceGeometryConfiguration) -> Void) -> Bool {
        guard let topology, var candidate = draft else { return false }
        mutation(&candidate)
        let issues = ResearchFaceGeometryValidator.validate(candidate, topology: topology, frame: selectedFrame)
        guard issues.isEmpty else { message = issues.map(\.message).joined(separator: "\n"); return false }
        draft = candidate
        message = nil
        return true
    }

    private func normalizedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
