//
//  SessionSummaryView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct SessionSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            if let vm = appState.currentSessionViewModel {
                let summary = vm.buildSessionSummary()
                VStack(alignment: .leading, spacing: 20) {
                    FaceworkSectionHeader("Session Summary", subtitle: "Capture results and local research exports.")

                    FaceworkCard {
                        VStack(alignment: .leading, spacing: 10) {
                            FaceworkStatusBadge(
                                title: statusTitle(for: summary.overallQC),
                                systemImage: summary.overallQC.validForAnalysis ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                color: summary.overallQC.validForAnalysis ? .green : .orange
                            )
                            Text("Participant: \(summary.sessionMetadata.participantID)")
                                .font(.headline)
                            Text("Overall QC: \(summary.overallQC.percentFramesPassing * 100, specifier: "%.0f")% valid frames")
                                .foregroundStyle(.secondary)
                        }
                    }

                    FaceworkSectionHeader("Tasks")

                    ForEach(summary.taskSummaries) { taskSummary in
                        taskSummaryCard(taskSummary)
                    }

                    if let error = vm.lastError {
                        Text("Export error: \(error)")
                            .foregroundStyle(.red)
                    }

                    FaceworkSectionHeader("Exports")
                    VStack(spacing: 10) {
                        Button("Save / Refresh Export Files") {
                            vm.saveSession()
                        }
                        .buttonStyle(FaceworkPrimaryButtonStyle())

                        Button("Share Exported Data") {
                            if vm.shareableExportURLs.isEmpty {
                                _ = vm.saveSession()
                            }
                            showingShareSheet = !vm.shareableExportURLs.isEmpty
                        }
                        .buttonStyle(FaceworkSecondaryButtonStyle())
                        .disabled(!vm.lastError.isNilOrEmpty)

                        Button("Return Home") {
                            vm.stopTracking()
                            appState.currentSessionViewModel = nil
                            appState.routeStack.removeAll()
                        }
                        .buttonStyle(FaceworkSecondaryButtonStyle())
                    }

                    if !vm.exportPaths.isEmpty {
                        Text("Saved Files")
                            .font(.headline)
                        ForEach(vm.exportPaths, id: \.self) { path in
                            Text(path)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()
                .faceworkScreenBackground()
                .sheet(isPresented: $showingShareSheet) {
                    ActivityView(activityItems: vm.shareableExportURLs.map { $0 as Any })
                }
            } else {
                VStack(spacing: 16) {
                    Text("No active session")
                    Button("Return Home") {
                        appState.routeStack.removeAll()
                    }
                    .buttonStyle(FaceworkPrimaryButtonStyle())
                }
                .padding()
                .faceworkScreenBackground()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func taskSummaryCard(_ taskSummary: TaskSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(taskSummary.taskType.displayName)
                .font(.headline)
            Text("Valid reps: \(taskSummary.validRepetitionCount)")
            Text("Invalid reps: \(taskSummary.invalidRepetitionCount)")

            if let symmetry = taskSummary.averageMetrics.symmetry {
                Text("Average symmetry: \(symmetry, specifier: "%.3f")")
            }

            if let amplitude = averagePeakAmplitude(taskSummary.averageMetrics) {
                Text("Average peak amplitude: \(amplitude, specifier: "%.3f")")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
    }

    private func averagePeakAmplitude(_ metrics: DerivedMetrics) -> Double? {
        [metrics.peakAmplitudeLeft, metrics.peakAmplitudeRight]
            .compactMap { $0 }
            .max()
    }

    private func statusTitle(for qc: QCSummary) -> String {
        if qc.validForAnalysis { return "Valid for analysis" }
        if qc.reasons.contains(.calibrationUnavailable) { return "Calibration unavailable" }
        if qc.reasons.contains(.missingRequiredTask) || qc.reasons.contains(.incompleteProtocol) {
            return "Session incomplete"
        }
        return "Review required"
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
