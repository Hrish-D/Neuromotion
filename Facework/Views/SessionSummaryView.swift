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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Session Summary")
                        .font(.largeTitle)
                        .bold()

                    Text("Participant: \(summary.sessionMetadata.participantID)")
                    Text("Overall QC: \(summary.overallQC.percentFramesPassing * 100, specifier: "%.0f")% valid frames")

                    ForEach(summary.taskSummaries) { taskSummary in
                        taskSummaryCard(taskSummary)
                    }

                    if let error = vm.lastError {
                        Text("Export error: \(error)")
                            .foregroundStyle(.red)
                    }

                    Button("Save / Refresh Export Files") {
                        vm.saveSession()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Share Exported Data") {
                        if vm.shareableExportURLs.isEmpty {
                            _ = vm.saveSession()
                        }
                        showingShareSheet = !vm.shareableExportURLs.isEmpty
                    }
                    .buttonStyle(.bordered)
                    .disabled(!vm.lastError.isNilOrEmpty)

                    Button("Return Home") {
                        vm.stopTracking()
                        appState.currentSessionViewModel = nil
                        appState.routeStack.removeAll()
                    }
                    .buttonStyle(.bordered)

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
                .sheet(isPresented: $showingShareSheet) {
                    ActivityView(activityItems: vm.shareableExportURLs.map { $0 as Any })
                }
            } else {
                VStack(spacing: 16) {
                    Text("No active session")
                    Button("Return Home") {
                        appState.routeStack.removeAll()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
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
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func averagePeakAmplitude(_ metrics: DerivedMetrics) -> Double? {
        [metrics.peakAmplitudeLeft, metrics.peakAmplitudeRight]
            .compactMap { $0 }
            .max()
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
