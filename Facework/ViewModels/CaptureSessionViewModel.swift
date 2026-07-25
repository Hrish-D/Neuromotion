//
//  CaptureSessionViewModel.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//
import Foundation
import SwiftUI
import Combine

final class CaptureSessionViewModel: ObservableObject {
    @Published var metadata: SessionMetadata
    @Published var readinessStatus = DeviceReadinessStatus()
    @Published var baselineFrames: [FrameCapture] = []
    @Published var baselineValues: [String: Double] = [:]
    @Published var currentTaskIndex: Int = 0
    @Published var repetitionsByTask: [TaskType: [RepetitionResult]] = [:]
    @Published var allFrames: [FrameCapture] = []
    @Published var exportPaths: [String] = []
    @Published var exportFileURLs: [URL] = []
    @Published var exportPackageURL: URL?
    @Published var lastError: String?

    let trackingManager = FaceTrackingManager()
    let frameLogWriter = FrameLogWriter()
    let imageCaptureService = ImageCaptureService()

    let tasks: [TaskType] = [.browRaise, .eyeClosure, .smileTeeth, .smileClosed, .lipPucker, .cheekPuff]
    let taskConfigurations: [TaskType: TaskConfiguration] = Dictionary(uniqueKeysWithValues: TaskType.allCases.map { ($0, .default(for: $0)) })

    private let calibrator = BaselineCalibrator()
    private let taskAnalyzer = TaskAnalyzer()
    private let sessionStore = SessionStore()

    init(metadata: SessionMetadata) {
        self.metadata = metadata
    }

    var currentTask: TaskType? {
        guard tasks.indices.contains(currentTaskIndex) else { return nil }
        return tasks[currentTaskIndex]
    }

    var exportFolderURL: URL? {
        exportFileURLs.first?.deletingLastPathComponent()
    }
    var shareableExportURLs: [URL] {
        if let exportPackageURL {
            return [exportPackageURL]
        }
        return exportFileURLs
    }
    

    func startTracking() {
        trackingManager.start()
    }

    func stopTracking() {
        trackingManager.stop()
    }

    func updateBaseline(frames: [FrameCapture]) {
        baselineFrames = frames
        baselineValues = calibrator.computeBaseline(from: frames)
        allFrames.append(contentsOf: frames)
    }

    func store(repetition: RepetitionResult, frames: [FrameCapture]) {
        repetitionsByTask[repetition.taskType, default: []].append(repetition)
        allFrames.append(contentsOf: frames)
    }

    func moveToNextTask() {
        currentTaskIndex += 1
    }

    func buildSessionSummary() -> SessionSummary {
        let taskSummaries = tasks.map { task in
            taskAnalyzer.summarize(task: task, repetitions: repetitionsByTask[task] ?? [])
        }
        let validFrames = allFrames.filter(\.isValidFrame).count
        let overallQC = QCSummary(
            overallPassed: !allFrames.isEmpty,
            reasons: [],
            percentFramesPassing: allFrames.isEmpty ? 0 : Double(validFrames) / Double(allFrames.count),
            validForAnalysis: !allFrames.isEmpty
        )
        return SessionSummary(sessionMetadata: metadata, taskSummaries: taskSummaries, exportPaths: exportPaths, overallQC: overallQC)
    }

    @discardableResult
    func saveSession() -> [URL] {
        do {
            let summary = buildSessionSummary()
            let repetitions = repetitionsByTask.values.flatMap { $0 }.sorted { a, b in
                if a.taskType == b.taskType { return a.repetitionIndex < b.repetitionIndex }
                return a.taskType.rawValue < b.taskType.rawValue
            }
            let urls = try sessionStore.save(metadata: metadata,
                                             config: taskConfigurations,
                                             frames: allFrames,
                                             repetitions: repetitions,
                                             summary: summary)

            exportPackageURL = urls.first { $0.pathExtension.lowercased() == "zip"}
            exportFileURLs = urls.filter { $0.pathExtension.lowercased() != "zip"}
            exportPaths = urls.map(\.path)
            
            lastError = nil
            return urls
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }
}
