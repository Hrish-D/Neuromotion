//
//  PreviousSessionsViewModel.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import SwiftUI
import Combine

final class PreviousSessionsViewModel: ObservableObject {
    @Published var sessionFolders: [URL] = []

    func loadSessions() {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let root = documents.appendingPathComponent(AppConfiguration.shared.exportRootFolderName, isDirectory: true)
        let participants = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        sessionFolders = participants.flatMap { participant in
            (try? fm.contentsOfDirectory(at: participant, includingPropertiesForKeys: nil)) ?? []
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
