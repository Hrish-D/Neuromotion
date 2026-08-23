//
//  AppRouter.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

enum AppRoute: Hashable {
    case home
    case setup
    case readiness
    case neutralCalibration
    case taskInstruction(TaskType)
    case taskExecution(TaskType)
    case sessionSummary
    case previousSessions
    case meshInspector(URL)
    case settings
}
