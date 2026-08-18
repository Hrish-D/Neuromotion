//
//  SessionSetupView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct SessionSetupView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SessionSetupViewModel()

    var body: some View {
        Form {
            Section("Session Metadata") {
                TextField("Study ID", text: $viewModel.studyID)
                TextField("Participant ID", text: $viewModel.participantID)
                TextField("Rater ID (optional)", text: $viewModel.raterID)
                TextField("Session Label (optional)", text: $viewModel.sessionLabel)
                Picker("Affected Side", selection: $viewModel.affectedSide) {
                    ForEach(AffectedSide.allCases) { side in
                        Text(side.displayName).tag(side)
                    }
                }
                TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                Button("Continue") {
                    let metadata = viewModel.buildMetadata()
                    appState.currentSessionViewModel = CaptureSessionViewModel(metadata: metadata)
                    appState.routeStack.append(.readiness)
                }
                .buttonStyle(FaceworkPrimaryButtonStyle())
                .disabled(!viewModel.canProceed)
            }
        }
        .navigationTitle("New Session Setup")
        .scrollContentBackground(.hidden)
        .faceworkScreenBackground()
    }
}
