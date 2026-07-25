//
//  FileManagerService.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

final class FileManagerService {
    private let fileManager = FileManager.default

    func sessionFolder(participantID: String, sessionID: String) throws -> URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = documents.appendingPathComponent(AppConfiguration.shared.exportRootFolderName, isDirectory: true)
        let participant = root.appendingPathComponent(participantID, isDirectory: true)
        let session = participant.appendingPathComponent(sessionID, isDirectory: true)

        try createDirectoryIfNeeded(root)
        try createDirectoryIfNeeded(participant)
        try createDirectoryIfNeeded(session)
        return session
    }

    func createDirectoryIfNeeded(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func write(data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}
