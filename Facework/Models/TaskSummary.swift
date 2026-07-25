//
//  TaskSummary.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct TaskSummary: Codable, Equatable, Identifiable {
    var id: String { taskType.rawValue }
    let taskType: TaskType
    let validRepetitionCount: Int
    let invalidRepetitionCount: Int
    let averageMetrics: DerivedMetrics
    let repeatabilityMetrics: [String: Double]
}
