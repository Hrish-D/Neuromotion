//
//  DerivedMetrics.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct DerivedMetrics: Codable, Equatable {
    let peakAmplitudeLeft: Double?
    let peakAmplitudeRight: Double?
    let peakVelocityLeft: Double?
    let peakVelocityRight: Double?
    let symmetry: Double?
    let onsetTimeLeft: Double?
    let onsetTimeRight: Double?
    let timeToPeakLeft: Double?
    let timeToPeakRight: Double?
    let meanActiveVelocityLeft: Double?
    let meanActiveVelocityRight: Double?
    let holdStability: Double?
    let fatigueSlope: Double?
    let confidenceScore: Double?

    static let empty = DerivedMetrics(
        peakAmplitudeLeft: nil,
        peakAmplitudeRight: nil,
        peakVelocityLeft: nil,
        peakVelocityRight: nil,
        symmetry: nil,
        onsetTimeLeft: nil,
        onsetTimeRight: nil,
        timeToPeakLeft: nil,
        timeToPeakRight: nil,
        meanActiveVelocityLeft: nil,
        meanActiveVelocityRight: nil,
        holdStability: nil,
        fatigueSlope: nil,
        confidenceScore: nil
    )
}
