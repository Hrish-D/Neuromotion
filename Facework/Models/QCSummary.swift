//
//  QCSummary.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct QCSummary: Codable, Equatable {
    let overallPassed: Bool
    let reasons: [QCFlag]
    let percentFramesPassing: Double
    let validForAnalysis: Bool
}
