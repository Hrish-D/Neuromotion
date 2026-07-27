//
//  SessionSetupViewModel.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import SwiftUI
import Combine


final class SessionSetupViewModel: ObservableObject {
    @Published var studyID: String = ""
    @Published var participantID: String = ""
    @Published var raterID: String = ""
    @Published var sessionLabel: String = ""
    @Published var affectedSide: AffectedSide = .none
    @Published var notes: String = ""

    private let metadataFactory: SessionMetadataFactory

    init(metadataFactory: SessionMetadataFactory = .current()) {
        self.metadataFactory = metadataFactory
    }

    var canProceed: Bool {
        !studyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !participantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func buildMetadata(
        sessionID: String = UUID().uuidString,
        sessionDate: Date = Date()
    ) -> SessionMetadata {
        metadataFactory.make(
            sessionID: sessionID,
            studyID: studyID,
            participantID: participantID,
            raterID: raterID.isEmpty ? nil : raterID,
            sessionDate: sessionDate,
            notes: notes.isEmpty ? nil : notes,
            affectedSide: affectedSide,
            sessionLabel: sessionLabel.isEmpty ? nil : sessionLabel
        )
    }
}
