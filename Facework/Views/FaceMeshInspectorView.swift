import SwiftUI
import UniformTypeIdentifiers

struct FaceMeshInspectorView: View {
    @StateObject private var viewModel: FaceMeshInspectorViewModel
    @State private var preset: FaceMeshViewPreset = .front
    @State private var searchText = ""
    @State private var landmarkName = ""
    @State private var regionName = ""
    @State private var side: FaceSubjectSide = .unspecified
    @State private var notes = ""
    @State private var geometryName = ""
    @State private var polylineChoice: DraftPointChoice?
    @State private var showingImporter = false
    @State private var showingShare = false
    @State private var resetViewGeneration = 0

    init(folderURL: URL) {
        _viewModel = StateObject(wrappedValue: FaceMeshInspectorViewModel(folderURL: folderURL))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FaceworkSectionHeader("Research Mesh Inspector", subtitle: "Draft research use only — no clinical mapping is active.")
                if let session = viewModel.session, let topology = viewModel.topology {
                    metadataCard(session: session, topology: topology)
                    selectors
                    if let frame = viewModel.selectedFrame {
                        StoredFaceMeshSceneView(frame: frame, topology: topology,
                                                selectedVertexIndex: viewModel.selectedVertexIndex,
                                                regionVertexIndices: viewModel.highlightedRegionVertices,
                                                draftConfiguration: viewModel.overlayConfiguration,
                                                preset: preset,
                                                resetViewGeneration: resetViewGeneration) { viewModel.selectedVertexIndex = $0 }
                            .frame(minHeight: 390)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("researchMeshViewport")
                        presetControls
                        vertexControls(topology: topology)
                        selectedVertexCard
                        referenceAndTrajectory
                        draftControls
                    }
                } else {
                    ContentUnavailableView("Mesh Data Unavailable", systemImage: "point.3.connected.trianglepath.dotted",
                                           description: Text(viewModel.message ?? "This session has no inspectable Prompt 11 mesh artifacts."))
                }
            }
            .padding()
        }
        .faceworkScreenBackground()
        .navigationTitle("Mesh Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { viewModel.importDraft(from: url) }
        }
        .sheet(isPresented: $showingShare) {
            if let url = viewModel.exportedDraftURL { ActivityView(activityItems: [url]) }
        }
    }

    private func metadataCard(session: StoredFaceMeshSession, topology: FaceMeshTopology) -> some View {
        FaceworkCard {
            VStack(alignment: .leading, spacing: 5) {
                FaceworkStatusBadge(title: "Research-only stored mesh", systemImage: "cube.transparent", color: .orange)
                Text("\(topology.vertexCount) vertices • \(topology.triangleCount) triangles")
                Text("Topology: \(topology.topologyID)").font(.caption2).textSelection(.enabled)
                Text("\(session.meshExport.frames.count) available mesh frames").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var selectors: some View {
        FaceworkCard {
            VStack(alignment: .leading, spacing: 10) {
                FaceworkSectionHeader("Stored frame")
                Picker("Task", selection: Binding(get: { viewModel.selectedTask }, set: { viewModel.selectTask($0) })) {
                    ForEach(viewModel.availableTasks) { Text($0.displayName).tag($0) }
                }
                Picker("Repetition", selection: Binding(get: { viewModel.selectedRepetition }, set: { viewModel.selectRepetition($0) })) {
                    ForEach(viewModel.availableRepetitions, id: \.self) { Text("Repetition \($0)").tag($0) }
                }
                Picker("Frame", selection: $viewModel.selectedFrameIndex) {
                    ForEach(viewModel.availableFrames, id: \.id) { Text("Frame \($0.frameIndex)").tag($0.frameIndex) }
                }
            }
        }
    }

    private var presetControls: some View {
        VStack(spacing: 8) {
        Picker("Orientation", selection: $preset) {
            ForEach(FaceMeshViewPreset.allCases) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
        Button("Reset View") {
            preset = .front
            resetViewGeneration += 1
        }
        .buttonStyle(FaceworkSecondaryButtonStyle())
        }
    }

    private func vertexControls(topology: FaceMeshTopology) -> some View {
        FaceworkCard {
            VStack(alignment: .leading, spacing: 10) {
                FaceworkSectionHeader("Vertex selection")
                HStack {
                    TextField("Index 0..<\(topology.vertexCount)", text: $searchText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Button("Go") { viewModel.search(indexText: searchText) }.buttonStyle(.borderedProminent)
                }
                Text("Tap near a visible mesh vertex or search by exact index.").font(.caption).foregroundStyle(.secondary)
                if let message = viewModel.message {
                    Text(message).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder private var selectedVertexCard: some View {
        if let index = viewModel.selectedVertexIndex, let vertex = viewModel.selectedVertex {
            FaceworkCard {
                VStack(alignment: .leading, spacing: 6) {
                    FaceworkSectionHeader("Selected vertex \(index)")
                    Text(String(format: "X %.9f m", vertex.x))
                    Text(String(format: "Y %.9f m", vertex.y))
                    Text(String(format: "Z %.9f m", vertex.z))
                    Text("Neighbors: \(viewModel.selectedNeighbors.map(String.init).joined(separator: ", "))").font(.caption).textSelection(.enabled)
                    if !viewModel.selectedLandmarks.isEmpty {
                        Text("Draft landmark: \(viewModel.selectedLandmarks.map(\.displayName).joined(separator: ", "))").font(.caption)
                    }
                    Text("Current draft region: \(viewModel.regionSelection.contains(index) ? "Included" : "Not included")").font(.caption)
                    if !viewModel.selectedSavedRegions.isEmpty {
                        Text("Saved regions: \(viewModel.selectedSavedRegions.map(\.displayName).joined(separator: ", "))").font(.caption)
                    }
                    if !viewModel.selectedGeometryNames.isEmpty {
                        Text("Used by: \(viewModel.selectedGeometryNames.joined(separator: ", "))").font(.caption)
                    }
                    Button(viewModel.regionSelection.contains(index) ? "Remove from Draft Region" : "Add to Draft Region") { viewModel.toggleRegionVertex() }
                        .buttonStyle(FaceworkSecondaryButtonStyle())
                    Button("Use Vertex in Geometry Builders") { viewModel.addCurrentVertexToGeometryChoices() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var referenceAndTrajectory: some View {
        FaceworkCard {
            VStack(alignment: .leading, spacing: 8) {
                FaceworkSectionHeader("Raw comparison", subtitle: "Explicit neutral reference; no averaging or smoothing.")
                Picker("Neutral reference", selection: $viewModel.referenceFrameID) {
                    Text("None").tag(UUID?.none)
                    ForEach(viewModel.referenceCandidates, id: \.id) { Text("Neutral frame \($0.frameIndex)").tag(Optional($0.id)) }
                }
                if let displacement = viewModel.displacement {
                    Text(String(format: "Δx %.3f mm  Δy %.3f mm  Δz %.3f mm", displacement.dx * 1_000, displacement.dy * 1_000, displacement.dz * 1_000))
                    Text(String(format: "Euclidean displacement %.3f mm", displacement.euclideanMillimeters))
                }
                DisclosureGroup("Trajectory (\(viewModel.trajectory.count) raw samples)") {
                    ForEach(Array(viewModel.trajectory.enumerated()), id: \.offset) { _, sample in
                        Text(String(format: "%.6f  [%.6f, %.6f, %.6f]", sample.sourceTimestamp, sample.position.x, sample.position.y, sample.position.z))
                            .font(.caption2.monospaced()).textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var draftControls: some View {
        FaceworkCard {
            VStack(alignment: .leading, spacing: 10) {
                FaceworkSectionHeader("Draft research configuration", subtitle: "Manual labels do not imply anatomical or clinical validation.")
                TextField("Research label", text: $landmarkName).textFieldStyle(.roundedBorder)
                Picker("Subject side", selection: $side) { ForEach(FaceSubjectSide.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                TextField("Optional notes", text: $notes, axis: .vertical).textFieldStyle(.roundedBorder)
                Button("Add Draft Landmark") { viewModel.addLandmark(name: landmarkName, side: side, category: nil, notes: notes) }
                    .buttonStyle(FaceworkSecondaryButtonStyle())
                Divider()
                Text("Selected region vertices (\(viewModel.regionSelection.count)): \(regionVertexDescriptions)").font(.caption).textSelection(.enabled)
                TextField("Draft region name", text: $regionName).textFieldStyle(.roundedBorder)
                Button("Create Draft Region") { viewModel.addRegion(name: regionName, side: side, notes: notes) }
                    .buttonStyle(FaceworkSecondaryButtonStyle())
                Button("Clear Draft Region") { viewModel.clearRegionSelection() }.buttonStyle(.bordered)
                Divider()
                TextField("Geometry definition name", text: $geometryName).textFieldStyle(.roundedBorder)
                DisclosureGroup("Line builder") {
                    pointPicker("Endpoint A", selection: $viewModel.lineEndpointA)
                    pointPicker("Endpoint B", selection: $viewModel.lineEndpointB)
                    Button("Create Line") { viewModel.addLine(name: geometryName) }.buttonStyle(.borderedProminent)
                }
                DisclosureGroup("Polyline builder") {
                    pointPicker("Point to add", selection: $polylineChoice)
                    HStack {
                        Button("Add Point") { if let polylineChoice { viewModel.addPolylinePoint(polylineChoice) } }
                        Button("Add Current Vertex") { viewModel.addCurrentVertexToPolyline() }
                    }.buttonStyle(.bordered)
                    ForEach(Array(viewModel.polylinePoints.enumerated()), id: \.offset) { index, choice in
                        HStack {
                            Text("\(index + 1). \(choice.displayName)").font(.caption)
                            Spacer()
                            Button("↑") { viewModel.movePolylinePoint(from: index, by: -1) }.disabled(index == 0)
                            Button("↓") { viewModel.movePolylinePoint(from: index, by: 1) }.disabled(index == viewModel.polylinePoints.count - 1)
                            Button(role: .destructive) { viewModel.removePolylinePoint(at: index) } label: { Image(systemName: "minus.circle") }
                        }
                    }
                    HStack {
                        Button("Clear") { viewModel.clearPolylineBuilder() }
                        Button("Create Polyline") { viewModel.addPolyline(name: geometryName) }.buttonStyle(.borderedProminent)
                    }
                }
                DisclosureGroup("Plane builder") {
                    pointPicker("Point A", selection: $viewModel.planePointA)
                    pointPicker("Point B", selection: $viewModel.planePointB)
                    pointPicker("Point C", selection: $viewModel.planePointC)
                    Button("Create Plane") { viewModel.addPlane(name: geometryName) }.buttonStyle(.borderedProminent)
                }
                Toggle("Show Draft Geometry", isOn: $viewModel.showDraftGeometry)
                savedDraftObjects
                Divider()
                Button("Export Draft Configuration") { viewModel.exportDraft(); showingShare = viewModel.exportedDraftURL != nil }
                    .buttonStyle(FaceworkPrimaryButtonStyle())
                Button("Import Draft Configuration") { showingImporter = true }.buttonStyle(FaceworkSecondaryButtonStyle())
                if let draft = viewModel.draft {
                    Text("Draft: \(draft.landmarks.count) landmarks, \(draft.regions.count) regions, \(draft.lines.count) lines, \(draft.polylines.count) polylines, \(draft.planes.count) planes")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = viewModel.message { Text(message).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
            }
        }
    }

    private var regionVertexDescriptions: String {
        let pairs = (viewModel.draft?.landmarks ?? []).compactMap { landmark -> (Int, String)? in
            guard case .meshVertex(let index) = landmark.source else { return nil }
            return (index, landmark.displayName)
        }
        let landmarks = Dictionary(grouping: pairs, by: \.0).mapValues { $0.map(\.1).joined(separator: ", ") }
        return viewModel.regionSelection.sorted().map { index in landmarks[index].map { "\(index) · \($0)" } ?? String(index) }.joined(separator: ", ")
    }

    private func pointPicker(_ title: String, selection: Binding<DraftPointChoice?>) -> some View {
        Picker(title, selection: selection) {
            Text("Choose point").tag(DraftPointChoice?.none)
            ForEach(viewModel.pointChoices) { Text($0.displayName).tag(Optional($0)) }
        }
    }

    private var savedDraftObjects: some View {
        DisclosureGroup("Saved draft objects") {
            if let draft = viewModel.draft {
                entityHeader("Landmarks")
                ForEach(draft.landmarks) { landmark in
                    entityRow(landmark.displayName + landmarkVertexSuffix(landmark)) { viewModel.deleteLandmark(id: landmark.id) }
                }
                entityHeader("Regions")
                ForEach(draft.regions) { region in
                    HStack {
                        Button("\(region.displayName) · \(region.vertexIndices.count) vertices") { viewModel.selectedSavedRegionID = region.id }
                        Spacer(); deleteButton { viewModel.deleteRegion(id: region.id) }
                    }
                }
                entityHeader("Lines")
                ForEach(draft.lines) { line in entityRow("\(line.displayName) · \(referenceName(line.endpointA)) → \(referenceName(line.endpointB))") { viewModel.deleteLine(id: line.id) } }
                entityHeader("Polylines")
                ForEach(draft.polylines) { path in entityRow("\(path.displayName) · \(path.points.map(referenceName).joined(separator: " → "))") { viewModel.deletePolyline(id: path.id) } }
                entityHeader("Planes")
                ForEach(draft.planes) { plane in entityRow("\(plane.displayName) · \([plane.pointA, plane.pointB, plane.pointC].map(referenceName).joined(separator: " / "))") { viewModel.deletePlane(id: plane.id) } }
            }
        }
    }

    private func entityHeader(_ title: String) -> some View { Text(title).font(.caption.bold()).padding(.top, 4) }
    private func entityRow(_ title: String, delete: @escaping () -> Void) -> some View {
        HStack { Text(title).font(.caption); Spacer(); deleteButton(action: delete) }
    }
    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) { Image(systemName: "trash") }
    }
    private func landmarkVertexSuffix(_ landmark: FaceLandmarkDefinition) -> String {
        if case .meshVertex(let index) = landmark.source { return " · \(index)" }
        return ""
    }
    private func referenceName(_ reference: FaceGeometryPointReference) -> String {
        switch reference {
        case .meshVertex(let index): return "Vertex \(index)"
        case .landmark(let id): return viewModel.draft?.landmarks.first(where: { $0.id == id })?.displayName ?? "Unknown landmark"
        }
    }
}
