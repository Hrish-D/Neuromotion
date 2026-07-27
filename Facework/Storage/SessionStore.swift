//
//  SessionStore.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

final class SessionStore {
    private let fileManagerService = FileManagerService()
    private let jsonExporter = JSONExporter()
    private let csvExporter = CSVExporter()

    func save(metadata: SessionMetadata,
              config: [TaskType: TaskConfiguration],
              frames: [FrameCapture],
              repetitions: [RepetitionResult],
              summary: SessionSummary) throws -> [URL] {
        let folder = try fileManagerService.sessionFolder(participantID: metadata.participantID, sessionID: metadata.sessionID)

        let metadataURL = folder.appendingPathComponent("metadata.json")
        let summaryURL = folder.appendingPathComponent("session_summary.json")
        let framesJSONURL = folder.appendingPathComponent("frames.json")
        let repetitionsJSONURL = folder.appendingPathComponent("repetitions.json")
        let frameCSVURL = folder.appendingPathComponent("merged_per_frame.csv")
        let repCSVURL = folder.appendingPathComponent("merged_per_repetition.csv")
        let configURL = folder.appendingPathComponent("task_configurations.json")
        let imageManifestURL = folder.appendingPathComponent("validation_images_manifest.csv")

        var writtenURLs: [URL] = [
            metadataURL,
            summaryURL,
            framesJSONURL,
            repetitionsJSONURL,
            frameCSVURL,
            repCSVURL,
            configURL,
            imageManifestURL
        ]

        try jsonExporter.export(metadata, to: metadataURL)
        try jsonExporter.export(config.mapKeys { $0.rawValue }, to: configURL)
        try jsonExporter.export(frames, to: framesJSONURL)
        try jsonExporter.export(repetitions, to: repetitionsJSONURL)
        try csvExporter.exportFrames(frames, metadata: metadata, to: frameCSVURL)
        try csvExporter.exportRepetitions(repetitions, metadata: metadata, to: repCSVURL)
        try csvExporter.exportImageManifest(frames, metadata: metadata, to: imageManifestURL)

        let perTask = Dictionary(grouping: repetitions, by: \.taskType)
        for task in perTask.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let reps = perTask[task] else { continue }
            let taskURL = folder.appendingPathComponent("\(task.rawValue)_repetitions.csv")
            try csvExporter.exportRepetitions(reps, metadata: metadata, to: taskURL)
            writtenURLs.append(taskURL)
        }

        let imageURLs = collectValidationImageURLs(from: frames)
        writtenURLs.append(contentsOf: imageURLs)

        let summaryForDisk = SessionSummary(sessionMetadata: summary.sessionMetadata,
                                            taskSummaries: summary.taskSummaries,
                                            exportPaths: writtenURLs.map(\.path),
                                            overallQC: summary.overallQC)
        try jsonExporter.export(summaryForDisk, to: summaryURL)

        let zipURL = folder.deletingLastPathComponent().appendingPathComponent("\(folder.lastPathComponent).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try StoredZIPWriter.zipDirectory(at: folder, to: zipURL)
        writtenURLs.append(zipURL)

        return writtenURLs
    }

    private func collectValidationImageURLs(from frames: [FrameCapture]) -> [URL] {
        let uniquePaths = Set(frames.compactMap { frame -> String? in
            guard let imageReference = frame.imageReference, !imageReference.isEmpty else { return nil }
            return imageReference
        })

        return uniquePaths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

private enum StoredZIPWriter {
    static func zipDirectory(at sourceDirectory: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isHiddenKey]

        guard let enumerator = fileManager.enumerator(at: sourceDirectory,
                                                      includingPropertiesForKeys: Array(resourceKeys),
                                                      options: [.skipsHiddenFiles]) else {
            throw CocoaError(.fileNoSuchFile)
        }

        var fileEntries: [(url: URL, relativePath: String)] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true, values.isHidden != true else { continue }

            let relativePath = fileURL.path
                .replacingOccurrences(of: sourceDirectory.path + "/", with: "")
                .replacingOccurrences(of: "\\", with: "/")

            guard !relativePath.isEmpty else { continue }
            fileEntries.append((fileURL, relativePath))
        }

        fileEntries.sort { $0.relativePath < $1.relativePath }

        var archive = Data()
        var centralDirectory = Data()
        var centralDirectoryRecords = 0

        for entry in fileEntries {
            let fileData = try Data(contentsOf: entry.url)
            let fileNameData = Data(entry.relativePath.utf8)
            let crc = CRC32.checksum(fileData)
            let localHeaderOffset = UInt32(truncatingIfNeeded: archive.count)
            let dosTime = DOSTimestamp(date: entry.url.fileModificationDate ?? Date())

            archive.appendUInt32LE(0x04034b50)
            archive.appendUInt16LE(20)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(dosTime.time)
            archive.appendUInt16LE(dosTime.date)
            archive.appendUInt32LE(crc)
            archive.appendUInt32LE(UInt32(truncatingIfNeeded: fileData.count))
            archive.appendUInt32LE(UInt32(truncatingIfNeeded: fileData.count))
            archive.appendUInt16LE(UInt16(truncatingIfNeeded: fileNameData.count))
            archive.appendUInt16LE(0)
            archive.append(fileNameData)
            archive.append(fileData)

            centralDirectory.appendUInt32LE(0x02014b50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(dosTime.time)
            centralDirectory.appendUInt16LE(dosTime.date)
            centralDirectory.appendUInt32LE(crc)
            centralDirectory.appendUInt32LE(UInt32(truncatingIfNeeded: fileData.count))
            centralDirectory.appendUInt32LE(UInt32(truncatingIfNeeded: fileData.count))
            centralDirectory.appendUInt16LE(UInt16(truncatingIfNeeded: fileNameData.count))
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(localHeaderOffset)
            centralDirectory.append(fileNameData)

            centralDirectoryRecords += 1
        }

        let centralDirectoryOffset = UInt32(truncatingIfNeeded: archive.count)
        let centralDirectorySize = UInt32(truncatingIfNeeded: centralDirectory.count)
        archive.append(centralDirectory)

        archive.appendUInt32LE(0x06054b50)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(UInt16(truncatingIfNeeded: centralDirectoryRecords))
        archive.appendUInt16LE(UInt16(truncatingIfNeeded: centralDirectoryRecords))
        archive.appendUInt32LE(centralDirectorySize)
        archive.appendUInt32LE(centralDirectoryOffset)
        archive.appendUInt16LE(0)

        try archive.write(to: destinationURL, options: [.atomic])
    }
}

private struct DOSTimestamp {
    let time: UInt16
    let date: UInt16

    init(date sourceDate: Date) {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: sourceDate)
        let year = max(1980, components.year ?? 1980)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2

        self.time = UInt16((hour << 11) | (minute << 5) | second)
        self.date = UInt16(((year - 1980) << 9) | (month << 5) | day)
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i in
        var crc = UInt32(i)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xEDB88320
            } else {
                crc >>= 1
            }
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value & 0xFF00) >> 8))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0x000000FF))
        append(UInt8((value & 0x0000FF00) >> 8))
        append(UInt8((value & 0x00FF0000) >> 16))
        append(UInt8((value & 0xFF000000) >> 24))
    }
}

private extension URL {
    var fileModificationDate: Date? {
        (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
