//
//  SessionSummary.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct SessionSummary: Codable, Equatable {
    let sessionMetadata: SessionMetadata
    let taskSummaries: [TaskSummary]
    let exportPaths: [String]
    let overallQC: QCSummary
}
