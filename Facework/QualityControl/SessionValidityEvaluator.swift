import Foundation

/// Evaluates protocol completeness separately from per-frame and per-repetition QC.
struct SessionValidityEvaluator {
    func evaluate(
        calibrationEstablished: Bool,
        requiredTasks: [TaskType],
        configurations: [TaskType: TaskConfiguration],
        repetitionsByTask: [TaskType: [RepetitionResult]],
        frames: [FrameCapture]
    ) -> QCSummary {
        var reasons: Set<QCFlag> = []
        if !calibrationEstablished {
            reasons.insert(.calibrationUnavailable)
        }

        for task in requiredTasks {
            let repetitions = repetitionsByTask[task] ?? []
            let requiredAttempts = configurations[task]?.repetitionsRequired ?? 0
            let hasScientificFrames = frames.contains { $0.taskType == task }

            if !hasScientificFrames {
                reasons.insert(.missingRequiredTask)
            }
            if repetitions.count < requiredAttempts {
                reasons.insert(.incompleteProtocol)
            }
            // TaskAnalyzer can derive task metrics from any valid repetition. This
            // preserves an isolated failed attempt while rejecting wholly unusable tasks.
            if !repetitions.contains(where: \.valid) {
                reasons.insert(.insufficientValidRepetitions)
            }
        }

        let validFrames = frames.filter(\.isValidFrame).count
        let percentage = frames.isEmpty ? 0 : Double(validFrames) / Double(frames.count)
        let sortedReasons = reasons.sorted { $0.rawValue < $1.rawValue }
        return QCSummary(
            overallPassed: sortedReasons.isEmpty,
            reasons: sortedReasons,
            percentFramesPassing: percentage,
            validForAnalysis: sortedReasons.isEmpty
        )
    }
}
