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
    @Published private(set) var calibrationResult: NeutralCalibrationResult?
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

    private let calibrationEvaluator = NeutralCalibrationEvaluator()
    private let sessionValidityEvaluator = SessionValidityEvaluator()
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

    @discardableResult
    func updateBaseline(
        frames: [FrameCapture],
        attempt: NeutralCalibrationAttemptEvidence
    ) -> NeutralCalibrationResult {
        allFrames.append(contentsOf: frames)
        let result = calibrationEvaluator.evaluate(frames: frames, attempt: attempt)
        calibrationResult = result

        switch result {
        case .success(let baseline, let eligibleFrames, _):
            baselineFrames = eligibleFrames
            baselineValues = baseline
        case .failure:
            baselineFrames = []
            baselineValues = [:]
        }
        return result
    }

    func prepareCalibrationRetry() {
        calibrationResult = nil
        baselineFrames = []
        baselineValues = [:]
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
        let overallQC = sessionValidityEvaluator.evaluate(
            calibrationEstablished: calibrationResult?.isSuccessful == true,
            requiredTasks: tasks,
            configurations: taskConfigurations,
            repetitionsByTask: repetitionsByTask,
            frames: allFrames
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
