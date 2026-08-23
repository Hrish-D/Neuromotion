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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Facial Motion Baseline")
                            .font(.largeTitle.weight(.bold))
                        Text("Deterministic facial movement assessment")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        NavigationLink(value: AppRoute.setup) {
                            actionCard(title: "Start New Session", subtitle: "Create metadata and begin capture", icon: "plus.circle.fill")
                        }
                        NavigationLink(value: AppRoute.previousSessions) {
                            actionCard(title: "Review Previous Sessions", subtitle: "Browse local session folders", icon: "clock.arrow.circlepath")
                        }
                        NavigationLink(value: AppRoute.settings) {
                            actionCard(title: "Settings", subtitle: "Research mode and app configuration", icon: "gearshape.fill")
                        }
                    }
                    .buttonStyle(.plain)

                    FaceworkCard {
                        VStack(alignment: .leading, spacing: 10) {
                            FaceworkSectionHeader("TrueDepth required")
                            Label("Face tracking requires a supported physical iPhone.", systemImage: "faceid")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .faceworkScreenBackground()
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
                case .meshInspector(let folderURL):
                    FaceMeshInspectorView(folderURL: folderURL)
                case .settings:
                    SettingsView()
                }
            }
        }
    }

    private func actionCard(title: String, subtitle: String, icon: String) -> some View {
        FaceworkCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
