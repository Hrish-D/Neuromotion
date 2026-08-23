import SwiftUI
import UniformTypeIdentifiers

struct FaceMeshInspectorView: View {
    @StateObject private var viewModel: FaceMeshInspectorViewModel
    @State private var preset: FaceMeshViewPreset = .front
    @State private var searchText = ""
    @State private var landmarkName = ""
    @State private var regionName = ""
    @State private var landmarkSide: FaceSubjectSide = .unspecified
    @State private var regionSide: FaceSubjectSide = .unspecified
    @State private var notes = ""
    @State private var geometryName = ""
    @State private var polylineChoice: DraftPointChoice?
    @State private var showingImporter = false
    @State private var shareItems: [URL] = []
    @State private var resetViewGeneration = 0
    @State private var landmarkPairName = ""
    @State private var regionPairName = ""
    @State private var leftLandmarkID = ""
    @State private var rightLandmarkID = ""
    @State private var leftRegionID = ""
    @State private var rightRegionID = ""
    @State private var scaleReferenceLineID = ""

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
                                                displacementOverlay: viewModel.selectedDisplacementOverlay,
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
                        prompt13AnalysisControls
                        candidateMeasurementPanel
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
        .sheet(isPresented: Binding(get: { !shareItems.isEmpty }, set: { if !$0 { shareItems = [] } })) {
            ActivityView(activityItems: shareItems)
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
                Picker("Landmark side", selection: $landmarkSide) { ForEach(FaceSubjectSide.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                TextField("Optional notes", text: $notes, axis: .vertical).textFieldStyle(.roundedBorder)
                Button("Add Draft Landmark") { viewModel.addLandmark(name: landmarkName, side: landmarkSide, category: nil, notes: notes) }
                    .buttonStyle(FaceworkSecondaryButtonStyle())
                Divider()
                Text("Selected region vertices (\(viewModel.regionSelection.count)): \(regionVertexDescriptions)").font(.caption).textSelection(.enabled)
                TextField("Draft region name", text: $regionName).textFieldStyle(.roundedBorder)
                Picker("Region side", selection: $regionSide) {
                    ForEach(FaceSubjectSide.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .accessibilityIdentifier("draftRegionSidePicker")
                Button("Create Draft Region") { viewModel.addRegion(name: regionName, side: regionSide, notes: notes) }
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
                Button("Export Draft Configuration") {
                    viewModel.exportDraft()
                    if let url = viewModel.exportedDraftURL { shareItems = [url] }
                }
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

    private var prompt13AnalysisControls: some View {
        FaceworkCard {
            VStack(alignment: .leading, spacing: 12) {
                FaceworkSectionHeader("Prompt 13 Analysis Configuration", subtitle: "Research-only quantitative geometry analysis")
                    .accessibilityIdentifier(Prompt13AnalysisControl.configuration.rawValue)
                Text("These controls are separate from the Prompt 12 draft geometry builders.")
                    .font(.caption).foregroundStyle(.secondary)

                DisclosureGroup("Bilateral Landmark Pairs") {
                    Text(sideEligibilityText(kind: "landmarks", leftCount: subjectLeftLandmarks.count, rightCount: subjectRightLandmarks.count))
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Pair name", text: $landmarkPairName).textFieldStyle(.roundedBorder)
            Picker("Subject-left landmark", selection: $leftLandmarkID) {
                Text("Choose").tag("")
                        ForEach(subjectLeftLandmarks) { Text(landmarkPickerLabel($0)).tag($0.id) }
            }
            Picker("Subject-right landmark", selection: $rightLandmarkID) {
                Text("Choose").tag("")
                        ForEach(subjectRightLandmarks) { Text(landmarkPickerLabel($0)).tag($0.id) }
            }
                    Button("Create Bilateral Landmark Pair") {
                        viewModel.addBilateralLandmarkPair(name: landmarkPairName, leftID: leftLandmarkID, rightID: rightLandmarkID)
                        landmarkPairName = ""; leftLandmarkID = ""; rightLandmarkID = ""
                    }.disabled(leftLandmarkID.isEmpty || rightLandmarkID.isEmpty)
                        .accessibilityIdentifier("createBilateralLandmarkPair")
                    ForEach(viewModel.bilateralLandmarkPairs) { pair in
                        pairRow(pair.displayName,
                                detail: "Left: \(landmarkName(pair.subjectLeftLandmarkID)) · Right: \(landmarkName(pair.subjectRightLandmarkID))") {
                            viewModel.deleteBilateralLandmarkPair(id: pair.id)
                        }
                    }
                    Text("Saved landmark pairs: \(viewModel.bilateralLandmarkPairs.count)").font(.caption.bold())
                }
                .accessibilityIdentifier(Prompt13AnalysisControl.bilateralLandmarkPairs.rawValue)

                DisclosureGroup("Bilateral Region Pairs") {
                    Text(sideEligibilityText(kind: "regions", leftCount: subjectLeftRegions.count, rightCount: subjectRightRegions.count))
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Pair name", text: $regionPairName).textFieldStyle(.roundedBorder)
            Picker("Subject-left region", selection: $leftRegionID) {
                Text("Choose").tag("")
                        ForEach(subjectLeftRegions) { Text(regionPickerLabel($0)).tag($0.id) }
            }
            Picker("Subject-right region", selection: $rightRegionID) {
                Text("Choose").tag("")
                        ForEach(subjectRightRegions) { Text(regionPickerLabel($0)).tag($0.id) }
            }
                    Button("Create Bilateral Region Pair") {
                        viewModel.addBilateralRegionPair(name: regionPairName, leftID: leftRegionID, rightID: rightRegionID)
                        regionPairName = ""; leftRegionID = ""; rightRegionID = ""
                    }.disabled(leftRegionID.isEmpty || rightRegionID.isEmpty)
                        .accessibilityIdentifier("createBilateralRegionPair")
                    ForEach(viewModel.bilateralRegionPairs) { pair in
                        pairRow(pair.displayName,
                                detail: "Left: \(draftRegionName(pair.subjectLeftRegionID)) · Right: \(draftRegionName(pair.subjectRightRegionID))") {
                            viewModel.deleteBilateralRegionPair(id: pair.id)
                        }
                    }
                    Text("Saved region pairs: \(viewModel.bilateralRegionPairs.count)").font(.caption.bold())
                }
                .accessibilityIdentifier(Prompt13AnalysisControl.bilateralRegionPairs.rawValue)

                DisclosureGroup("Scale Reference") {
                    Text("Optional. None preserves raw millimetre analysis without normalization.").font(.caption).foregroundStyle(.secondary)
            Picker("Optional scale-reference line", selection: $scaleReferenceLineID) {
                Text("None").tag("")
                ForEach(viewModel.draft?.lines ?? []) { Text($0.displayName).tag($0.id) }
            }
                    Text("Selected: \(scaleReferenceLineID.isEmpty ? "None" : lineName(scaleReferenceLineID))").font(.caption)
                }
                .accessibilityIdentifier(Prompt13AnalysisControl.scaleReference.rawValue)

                DisclosureGroup("Candidate Configuration") {
                    candidateDraftReview
            Button("Freeze as Candidate for Analysis") {
                viewModel.freezeCandidate(scaleReferenceLineID: scaleReferenceLineID.isEmpty ? nil : scaleReferenceLineID)
                    }.buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("freezeCandidateForAnalysis")
            if let candidate = viewModel.candidate {
                        candidateReview(candidate)
                    }
                }
                .accessibilityIdentifier(Prompt13AnalysisControl.candidateConfiguration.rawValue)

                DisclosureGroup("Neutral Reference") {
                    Text(viewModel.candidate == nil ? "Requires a frozen candidate configuration." : "Select frames from the final successful neutral calibration attempt.")
                        .font(.caption).foregroundStyle(viewModel.candidate == nil ? Color.secondary : Color.orange)
                    Text("Eligible frames: \(viewModel.neutralMeshCandidates.count) · Selected: \(viewModel.selectedNeutralMeshFrameIDs.count)")
                        .font(.caption)
                    if let span = selectedNeutralSpan { Text(String(format: "Selected timestamp span: %.6f s", span)).font(.caption) }
                ForEach(viewModel.neutralMeshCandidates) { frame in
                    Toggle("Frame \(frame.frameIndex) · \(String(format: "%.6f", frame.sourceTimestamp))", isOn: Binding(
                        get: { viewModel.selectedNeutralMeshFrameIDs.contains(frame.id) },
                        set: { _ in viewModel.toggleNeutralFrame(frame.id) }
                    ))
                            .disabled(viewModel.candidate == nil)
                }
                    Button("Create Neutral Reference") { viewModel.createNeutralReference() }
                        .disabled(viewModel.candidate == nil || viewModel.selectedNeutralMeshFrameIDs.isEmpty)
                        .accessibilityIdentifier("createNeutralReference")
                    if let reference = viewModel.neutralReference {
                        Text("Neutral Reference ID: \(reference.neutralReferenceID)").font(.caption2).textSelection(.enabled)
                        Text(String(format: "%d frames · %.6f s", reference.neutralFrameCount, reference.neutralTimeSpanSeconds)).font(.caption)
                        ForEach(reference.researchQCWarnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                    }
                }
                .accessibilityIdentifier(Prompt13AnalysisControl.neutralReference.rawValue)

                DisclosureGroup("Analysis") {
                    Text(analysisReadinessText).font(.caption).foregroundStyle(.secondary)
                    Button("Analyze Candidate Geometry Offline") { viewModel.analyzeCandidate() }
                    .buttonStyle(FaceworkPrimaryButtonStyle())
                        .disabled(viewModel.candidate == nil || viewModel.neutralReference == nil)
                        .accessibilityIdentifier("analyzeCandidateGeometryOffline")
                    if let package = viewModel.measurementPackage {
                        Text("Complete: \(package.frames.count) available mesh-frame results · \(package.unavailableMeshFrames.count) unavailable mesh frames")
                            .font(.caption)
                    }
                }
                .accessibilityIdentifier(Prompt13AnalysisControl.analysis.rawValue)

                DisclosureGroup("Prompt 13 Analysis Exports") {
                    exportButton("Export Candidate Configuration", enabled: viewModel.candidate != nil) { viewModel.exportCandidateArtifact() }
                    exportButton("Export Neutral Reference", enabled: viewModel.neutralReference != nil) { viewModel.exportNeutralReferenceArtifact() }
                    exportButton("Export Geometry Measurements", enabled: viewModel.measurementPackage != nil) { viewModel.exportMeasurementRecordsArtifact() }
                    exportButton("Export Measurement Summary", enabled: viewModel.measurementPackage != nil) { viewModel.exportMeasurementSummaryArtifact() }
                    Text("These are separate derived research artifacts from Export Draft Configuration.").font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier(Prompt13AnalysisControl.exports.rawValue)

                if let message = viewModel.message { Text(message).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
            }
        }
    }

    private var subjectLeftLandmarks: [FaceLandmarkDefinition] { (viewModel.draft?.landmarks ?? []).filter { $0.side == .subjectLeft } }
    private var subjectRightLandmarks: [FaceLandmarkDefinition] { (viewModel.draft?.landmarks ?? []).filter { $0.side == .subjectRight } }
    private var subjectLeftRegions: [FaceRegionDefinition] { (viewModel.draft?.regions ?? []).filter { $0.side == .subjectLeft } }
    private var subjectRightRegions: [FaceRegionDefinition] { (viewModel.draft?.regions ?? []).filter { $0.side == .subjectRight } }

    private func landmarkPickerLabel(_ landmark: FaceLandmarkDefinition) -> String {
        let index: String
        if case .meshVertex(let value) = landmark.source { index = "vertex \(value)" } else { index = "unknown vertex" }
        return "\(landmark.displayName) · \(landmark.side.displayName) · \(index)"
    }
    private func regionPickerLabel(_ region: FaceRegionDefinition) -> String {
        "\(region.displayName) · \(region.side.displayName) · \(region.vertexIndices.count) vertices"
    }
    private func sideEligibilityText(kind: String, leftCount: Int, rightCount: Int) -> String {
        guard leftCount > 0, rightCount > 0 else { return "Requires at least one Subject Left and one Subject Right \(kind)." }
        return "Available: \(leftCount) Subject Left · \(rightCount) Subject Right"
    }
    private func landmarkName(_ id: String) -> String { viewModel.draft?.landmarks.first { $0.id == id }?.displayName ?? id }
    private func draftRegionName(_ id: String) -> String { viewModel.draft?.regions.first { $0.id == id }?.displayName ?? id }
    private func lineName(_ id: String) -> String { viewModel.draft?.lines.first { $0.id == id }?.displayName ?? id }

    private func pairRow(_ title: String, detail: String, delete: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) { Text(title).font(.subheadline.bold()); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer(); deleteButton(action: delete)
        }
    }

    @ViewBuilder private var candidateDraftReview: some View {
        if let draft = viewModel.draft {
            Text("Draft source: \(draft.configurationID) · \(draft.draftRevision)").font(.caption2).textSelection(.enabled)
            Text("Topology: \(draft.requiredTopologyID)").font(.caption2).textSelection(.enabled)
            Text("\(draft.landmarks.count) landmarks · \(draft.regions.count) regions · \(draft.lines.count) lines") .font(.caption)
            Text("\(draft.polylines.count) polylines · \(draft.planes.count) planes").font(.caption)
            Text("\(viewModel.bilateralLandmarkPairs.count) bilateral landmark pairs · \(viewModel.bilateralRegionPairs.count) bilateral region pairs").font(.caption)
            Text("Scale reference: \(scaleReferenceLineID.isEmpty ? "None" : lineName(scaleReferenceLineID))").font(.caption)
            Text("Research-only. Not clinically validated.").font(.caption.bold()).foregroundStyle(.orange)
        }
    }

    private func candidateReview(_ candidate: CandidateFaceGeometryConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status: Candidate for Review").font(.headline)
            Text("Candidate ID: \(candidate.configurationID)").font(.caption2).textSelection(.enabled)
            Text("Configuration version: \(candidate.configurationVersion)").font(.caption)
            Text("Configuration hash: \(candidate.configurationHash)").font(.caption2).textSelection(.enabled)
            Text("Required topology: \(candidate.requiredTopologyID)").font(.caption2).textSelection(.enabled)
            Text("Source draft: \(candidate.sourceDraftConfigurationID) · \(candidate.sourceDraftRevision)").font(.caption2).textSelection(.enabled)
            Text("Research-only. Not clinically validated.").font(.caption.bold()).foregroundStyle(.orange)
        }
        .accessibilityIdentifier("candidateConfigurationReview")
    }

    private var selectedNeutralSpan: TimeInterval? {
        let timestamps = viewModel.neutralMeshCandidates.filter { viewModel.selectedNeutralMeshFrameIDs.contains($0.id) }.map(\.sourceTimestamp)
        guard let first = timestamps.min(), let last = timestamps.max() else { return nil }
        return last - first
    }
    private var analysisReadinessText: String {
        if viewModel.candidate == nil { return "Requires a frozen candidate configuration." }
        if viewModel.neutralReference == nil { return "Requires a created neutral reference." }
        return viewModel.measurementPackage == nil ? "Ready for offline analysis." : "Offline analysis complete."
    }
    private func exportButton(_ title: String, enabled: Bool, action: @escaping () -> URL?) -> some View {
        Button(title) { if let url = action() { shareItems = [url] } }
            .disabled(!enabled)
            .buttonStyle(.bordered)
    }

    @ViewBuilder private var candidateMeasurementPanel: some View {
        if let package = viewModel.measurementPackage {
            FaceworkCard {
                VStack(alignment: .leading, spacing: 7) {
                    FaceworkSectionHeader("Candidate geometry measurements", subtitle: "Derived research quantities; no clinical score or interpretation.")
                    Text("Neutral: \(package.neutralReference.neutralFrameCount) frames · \(String(format: "%.3f", package.neutralReference.neutralTimeSpanSeconds)) s")
                    Text("Reference: \(package.neutralReference.neutralReferenceID)").font(.caption2).textSelection(.enabled)
                    if let candidate = viewModel.candidate {
                        DisclosureGroup("Candidate landmarks") {
                            ForEach(candidate.landmarks) { landmark in
                                Button(landmark.displayName + landmarkVertexSuffix(landmark)) {
                                    viewModel.selectCandidateLandmark(landmark)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    if let result = viewModel.selectedFrameMeasurements {
                        if let selected = viewModel.selectedCandidateLandmarks.first,
                           let value = result.landmarks.first(where: { $0.landmarkID == selected.id }),
                           let raw = value.raw, let baseline = value.baseline, let delta = value.delta {
                                DisclosureGroup("Landmark · \(selected.displayName)\(landmarkVertexSuffix(selected))") {
                                    Text(vectorText("Raw", raw)); Text(vectorText("Neutral", baseline)); Text(vectorText("Change from neutral", delta))
                                    Text(measurementText("3D displacement", value.displacementMagnitudeMeters))
                                    Text(measurementText("Outward lateral", value.outwardLateralDisplacementMeters))
                                    Text(measurementText("Superior", value.superiorDisplacementMeters))
                                    Text(measurementText("Anterior", value.anteriorDisplacementMeters))
                                }
                        } else {
                            Text("Select a candidate landmark vertex to inspect raw, neutral, and displacement measurements.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(result.bilateralLandmarks) { value in
                            let pair = viewModel.candidateLandmarkPair(value.pairID)
                            DisclosureGroup("Bilateral Landmark Pair · \(pair?.displayName ?? value.pairID)") {
                                if let pair {
                                    Text("Subject Left: \(viewModel.candidateLandmarkName(pair.subjectLeftLandmarkID))")
                                    Text("Subject Right: \(viewModel.candidateLandmarkName(pair.subjectRightLandmarkID))")
                                }
                                Text(measurementText("Left magnitude", value.leftMagnitudeMeters))
                                Text(measurementText("Right magnitude", value.rightMagnitudeMeters))
                                Text(measurementText("Magnitude difference", value.magnitudeDifferenceMeters))
                                Text(measurementText("Vector mismatch", value.vectorMismatchMeters))
                                Text(indexText("Asymmetry index", value.asymmetryIndex))
                            }
                        }
                        ForEach(result.regions) { value in
                            DisclosureGroup("Region · \(viewModel.candidateRegionName(value.regionID))") {
                                Text(measurementText("Centroid displacement", value.centroidDisplacementMagnitudeMeters))
                                Text(measurementText("RMS vertex displacement", value.rmsVertexDisplacementMeters))
                                Text(measurementText("Mean vertex displacement", value.meanVertexDisplacementMagnitudeMeters))
                                Text(measurementText("Maximum vertex displacement", value.maximumVertexDisplacementMagnitudeMeters))
                            }
                        }
                        ForEach(result.bilateralRegions) { value in
                            let pair = viewModel.candidateRegionPair(value.pairID)
                            DisclosureGroup("Bilateral Region Pair · \(pair?.displayName ?? value.pairID)") {
                                if let pair {
                                    Text("Subject Left: \(viewModel.candidateRegionName(pair.subjectLeftRegionID))")
                                    Text("Subject Right: \(viewModel.candidateRegionName(pair.subjectRightRegionID))")
                                }
                                Text(measurementText("Left centroid displacement", value.leftCentroidMagnitudeMeters))
                                Text(measurementText("Right centroid displacement", value.rightCentroidMagnitudeMeters))
                                Text(measurementText("Absolute centroid difference", value.absoluteCentroidDifferenceMeters))
                                Text(measurementText("Centroid vector mismatch", value.centroidVectorMismatchMeters))
                                Text(indexText("Centroid asymmetry index", value.centroidAsymmetryIndex))
                                Text(measurementText("Left RMS displacement", value.leftRMSMeters))
                                Text(measurementText("Right RMS displacement", value.rightRMSMeters))
                                Text(measurementText("Absolute RMS difference", value.absoluteRMSDifferenceMeters))
                                Text(indexText("RMS asymmetry index", value.rmsAsymmetryIndex))
                            }
                        }
                    }
                    Text("Derived exports: \(viewModel.derivedExportURLs.map(\.lastPathComponent).joined(separator: ", "))").font(.caption)
                }
            }
        }
    }

    private func vectorText(_ name: String, _ value: GeometryVector3) -> String {
        String(format: "%@ [%.3f, %.3f, %.3f] mm", name, value.x * 1_000, value.y * 1_000, value.z * 1_000)
    }

    private func measurementText(_ name: String, _ value: Double?) -> String {
        value.map { String(format: "%@ %.3f mm", name, $0 * 1_000) } ?? "\(name): unavailable"
    }

    private func indexText(_ name: String, _ value: Double?) -> String {
        value.map { String(format: "%@ %.6f (dimensionless)", name, $0) } ?? "\(name): unavailable"
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
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Button("\(region.displayName) · \(region.side.displayName) · \(region.vertexIndices.count) vertices") {
                                viewModel.selectedSavedRegionID = region.id
                            }
                            Spacer(); deleteButton { viewModel.deleteRegion(id: region.id) }
                        }
                        Picker("Side for \(region.displayName)", selection: Binding(
                            get: { region.side },
                            set: { viewModel.updateDraftRegionSide(id: region.id, side: $0) }
                        )) {
                            ForEach(FaceSubjectSide.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .font(.caption)
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
