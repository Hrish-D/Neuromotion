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
        VStack(alignment: .leading, spacing: 16) {
            Text(task.displayName)
                .font(.largeTitle)
                .bold()
            Text(task.instructionText)
            Text("Hold duration: \(TaskConfiguration.default(for: task).holdDuration, specifier: "%.1f") s")
            Text("Repetitions required: \(TaskConfiguration.default(for: task).repetitionsRequired)")

            Button("Begin Task") {
                appState.routeStack.append(.taskExecution(task))
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("Task Instructions")
    }
}
