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

    var canProceed: Bool {
        !studyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !participantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func buildMetadata() -> SessionMetadata {
        SessionMetadata(
            sessionID: UUID().uuidString,
            studyID: studyID,
            participantID: participantID,
            raterID: raterID.isEmpty ? nil : raterID,
            appVersion: AppConfiguration.shared.appVersion,
            deviceModel: DeviceInfoProvider.deviceModel(),
            osVersion: DeviceInfoProvider.osVersion(),
            sessionDate: Date(),
            notes: notes.isEmpty ? nil : notes,
            affectedSide: affectedSide,
            sessionLabel: sessionLabel.isEmpty ? nil : sessionLabel
        )
    }
}
