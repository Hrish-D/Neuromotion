//
//  TaskInstructionView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct TaskInstructionView: View {
    @EnvironmentObject private var appState: AppState
    let task: TaskType

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FaceworkSectionHeader(task.displayName, subtitle: "Review the movement before beginning capture.")

            FaceworkCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label(task.instructionText, systemImage: "figure.mind.and.body")
                    Divider()
                    Label("Hold for \(TaskConfiguration.default(for: task).holdDuration, specifier: "%.1f") seconds", systemImage: "timer")
                    Label("\(TaskConfiguration.default(for: task).repetitionsRequired) repetitions", systemImage: "repeat")
                }
            }

            Button("Begin Task") {
                appState.routeStack.append(.taskExecution(task))
            }
            .buttonStyle(FaceworkPrimaryButtonStyle())

            Spacer()
        }
        .padding()
        .faceworkScreenBackground()
        .navigationTitle("Task Instructions")
    }
}
