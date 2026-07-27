//
//  PreviousSessionsViewModel.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import SwiftUI
import Combine

struct PreviousSessionsLoadResult {
    let sessionFolders: [URL]
    let metadataBySessionFolder: [URL: SessionMetadata]
    let malformedMetadataFolders: [URL]
}

struct PreviousSessionMetadataLoader {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(from root: URL) -> PreviousSessionsLoadResult {
        let participants = (
            try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        ) ?? []
        let sessionFolders = participants.flatMap { participant in
            (
                try? fileManager.contentsOfDirectory(
                    at: participant,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            ) ?? []
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }

        var loadedMetadata: [URL: SessionMetadata] = [:]
        var malformedFolders: [URL] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for folder in sessionFolders {
            let metadataURL = folder.appendingPathComponent("metadata.json")
            do {
                let data = try Data(contentsOf: metadataURL)
                loadedMetadata[folder] = try decoder.decode(SessionMetadata.self, from: data)
            } catch {
                malformedFolders.append(folder)
            }
        }

        return PreviousSessionsLoadResult(
            sessionFolders: sessionFolders,
            metadataBySessionFolder: loadedMetadata,
            malformedMetadataFolders: malformedFolders
        )
    }
}

final class PreviousSessionsViewModel: ObservableObject {
    @Published var sessionFolders: [URL] = []
    @Published private(set) var metadataBySessionFolder: [URL: SessionMetadata] = [:]
    @Published private(set) var malformedMetadataFolders: [URL] = []

    private let rootDirectory: URL?
    private let fileManager: FileManager
    private let metadataLoader: PreviousSessionMetadataLoader

    init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.metadataLoader = PreviousSessionMetadataLoader(fileManager: fileManager)
    }

    func loadSessions() {
        guard let root = resolvedRootDirectory() else {
            sessionFolders = []
            metadataBySessionFolder = [:]
            malformedMetadataFolders = []
            return
        }

        let result = metadataLoader.load(from: root)
        sessionFolders = result.sessionFolders
        metadataBySessionFolder = result.metadataBySessionFolder
        malformedMetadataFolders = result.malformedMetadataFolders
    }

    private func resolvedRootDirectory() -> URL? {
        if let rootDirectory {
            return rootDirectory
        }

        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(
                AppConfiguration.shared.exportRootFolderName,
                isDirectory: true
            )
    }
}
