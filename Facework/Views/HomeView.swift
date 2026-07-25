//
//  HomeView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack(path: $appState.routeStack) {
            VStack(spacing: 20) {
                Text("Facial Motion Baseline")
                    .font(.largeTitle)
                    .bold()

                Text("Deterministic baseline facial movement measurement")
                    .foregroundStyle(.secondary)

                NavigationLink(value: AppRoute.setup) {
                    actionCard(title: "Start New Session", subtitle: "Create metadata and begin capture")
                }
                NavigationLink(value: AppRoute.previousSessions) {
                    actionCard(title: "Review Previous Sessions", subtitle: "Browse local session folders")
                }
                NavigationLink(value: AppRoute.settings) {
                    actionCard(title: "Settings", subtitle: "Research mode and app configuration")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Device / Tracking Status")
                        .font(.headline)
                    Text("Face tracking requires a TrueDepth-supported front camera.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding()
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    HomeView()
                case .setup:
                    SessionSetupView()
                case .readiness:
                    DeviceReadinessView()
                case .neutralCalibration:
                    NeutralCalibrationView()
                case .taskInstruction(let task):
                    TaskInstructionView(task: task)
                case .taskExecution(let task):
                    TaskExecutionView(task: task)
                case .sessionSummary:
                    SessionSummaryView()
                case .previousSessions:
                    PreviousSessionsView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }

    private func actionCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
