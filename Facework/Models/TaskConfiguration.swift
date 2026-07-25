//
//  TaskConfiguration.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct TaskConfiguration: Codable, Equatable {
    let repetitionsRequired: Int
    let holdDuration: TimeInterval
    let restDuration: TimeInterval
    let onsetThreshold: Double
    let holdThreshold: Double
    let enabledMetrics: [String]

    static func `default`(for task: TaskType) -> TaskConfiguration {
        switch task {
        case .neutralRest:
            return TaskConfiguration(repetitionsRequired: 1,
                                     holdDuration: AppConfiguration.shared.neutralCaptureDuration,
                                     restDuration: 0,
                                     onsetThreshold: 0,
                                     holdThreshold: 0,
                                     enabledMetrics: [])
        case .browRaise, .eyeClosure, .smileTeeth, .smileClosed, .lipPucker, .cheekPuff:
            return TaskConfiguration(repetitionsRequired: 3,
                                     holdDuration: 2.0,
                                     restDuration: 1.5,
                                     onsetThreshold: AppConfiguration.shared.onsetThresholdDefault,
                                     holdThreshold: AppConfiguration.shared.holdThresholdDefault,
                                     enabledMetrics: [
                                        "amplitude", "onsetTime", "timeToPeak", "peakVelocity",
                                        "meanActiveVelocity", "holdStability", "symmetry", "confidenceScore"
                                     ])
        }
    }
}
