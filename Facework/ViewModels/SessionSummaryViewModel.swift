//
//  SessionSummaryViewModel.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import SwiftUI
import Combine

final class SessionSummaryViewModel: ObservableObject {
    @Published var summary: SessionSummary

    init(summary: SessionSummary) {
        self.summary = summary
    }
}
