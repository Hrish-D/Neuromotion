//
//  RepetitionResults.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct RepetitionResult: Codable, Equatable, Identifiable {
    let id: UUID
    let repetitionIndex: Int
    let taskType: TaskType
    let startTime: TimeInterval
    let endTime: TimeInterval
    let valid: Bool
    let partial: Bool
    let failureReason: String?
    let qcSummary: QCSummary
    let derivedMetrics: DerivedMetrics

    // Validation linkage: these point back to the frame/image that produced the visual check.
    let peakFrameReference: String?
    let peakFrameIndex: Int?
    let peakFrameTimestamp: TimeInterval?
    let peakSignalValue: Double?
}
