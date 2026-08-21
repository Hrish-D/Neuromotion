import Foundation

/// Selects trustworthy neutral observations without interpreting stable,
/// non-zero ARKit coefficients as acquisition failure.
struct NeutralCalibrationEvaluator {
    private let calibrator = BaselineCalibrator()

    func evaluate(
        frames: [FrameCapture],
        attempt: NeutralCalibrationAttemptEvidence,
        configuredDuration: TimeInterval = AppConfiguration.shared.neutralCaptureDuration,
        maximumGap: TimeInterval = AppConfiguration.shared.maxFrameGapSeconds
    ) -> NeutralCalibrationResult {
        let requiredTrackedDuration = max(0, configuredDuration - maximumGap)
        guard !frames.isEmpty else {
            return .failure(reason: .noCapturedFrames, diagnostics: diagnostics(
                allFrames: [], eligibleFrames: [], rejectionReasons: [],
                attempt: attempt, continuousTrackedDuration: 0,
                requiredTrackedDuration: requiredTrackedDuration
            ))
        }

        var eligibleFrames: [FrameCapture] = []
        var rejectionReasons: Set<QCFlag> = []
        var previousTimestamp: TimeInterval?

        for frame in frames {
            let timestampIsUsable = frame.timestamp.isFinite &&
                previousTimestamp.map { frame.timestamp > $0 } ?? true
            previousTimestamp = frame.timestamp

            let hardFlags = frame.qcFlags.filter(\.invalidatesFrame)
            if timestampIsUsable && hardFlags.isEmpty {
                eligibleFrames.append(frame)
            } else {
                rejectionReasons.formUnion(hardFlags)
                if !timestampIsUsable {
                    rejectionReasons.insert(.invalidTimestampGap)
                }
            }
        }

        let attemptEvaluation = evaluateAttempt(attempt, maximumGap: maximumGap)
        let currentDiagnostics = diagnostics(
            allFrames: frames,
            eligibleFrames: eligibleFrames,
            rejectionReasons: Array(rejectionReasons.union(attemptEvaluation.rejectionReasons)),
            attempt: attempt,
            continuousTrackedDuration: attemptEvaluation.continuousTrackedDuration,
            requiredTrackedDuration: requiredTrackedDuration
        )
        guard attemptEvaluation.hardFailureCount == 0 else {
            return .failure(reason: .trackingInterrupted, diagnostics: currentDiagnostics)
        }
        guard attemptEvaluation.continuousTrackedDuration + 1e-9 >= requiredTrackedDuration else {
            return .failure(reason: .insufficientTrackedDuration, diagnostics: currentDiagnostics)
        }
        guard let baseline = calibrator.computeBaseline(fromEligibleFrames: eligibleFrames) else {
            return .failure(reason: .noEligibleFrames, diagnostics: currentDiagnostics)
        }

        return .success(
            baseline: baseline,
            eligibleFrames: eligibleFrames,
            diagnostics: NeutralCalibrationDiagnostics(
                totalFrameCount: currentDiagnostics.totalFrameCount,
                eligibleFrameCount: currentDiagnostics.eligibleFrameCount,
                rejectedFrameCount: currentDiagnostics.rejectedFrameCount,
                warningCount: currentDiagnostics.warningCount,
                eligibleDurationSeconds: currentDiagnostics.eligibleDurationSeconds,
                observedEventCount: currentDiagnostics.observedEventCount,
                hardFailureEventCount: currentDiagnostics.hardFailureEventCount,
                continuousTrackedDurationSeconds: currentDiagnostics.continuousTrackedDurationSeconds,
                requiredTrackedDurationSeconds: currentDiagnostics.requiredTrackedDurationSeconds,
                rejectionReasons: currentDiagnostics.rejectionReasons,
                warningFlags: currentDiagnostics.warningFlags,
                baselineEstablished: true
            )
        )
    }

    private func diagnostics(
        allFrames: [FrameCapture],
        eligibleFrames: [FrameCapture],
        rejectionReasons: [QCFlag],
        attempt: NeutralCalibrationAttemptEvidence,
        continuousTrackedDuration: TimeInterval,
        requiredTrackedDuration: TimeInterval
    ) -> NeutralCalibrationDiagnostics {
        let warningFlags = Array(Set(allFrames.flatMap(\.qcFlags).filter { !$0.invalidatesFrame }))
        let duration: TimeInterval
        if let first = eligibleFrames.first?.timestamp,
           let last = eligibleFrames.last?.timestamp,
           last >= first {
            duration = last - first
        } else {
            duration = 0
        }

        return NeutralCalibrationDiagnostics(
            totalFrameCount: allFrames.count,
            eligibleFrameCount: eligibleFrames.count,
            rejectedFrameCount: allFrames.count - eligibleFrames.count,
            warningCount: allFrames.reduce(0) { count, frame in
                count + frame.qcFlags.filter { !$0.invalidatesFrame }.count
            },
            eligibleDurationSeconds: duration,
            observedEventCount: attempt.events.count,
            hardFailureEventCount: attempt.events.filter { !isTrustworthy($0) }.count,
            continuousTrackedDurationSeconds: continuousTrackedDuration,
            requiredTrackedDurationSeconds: requiredTrackedDuration,
            rejectionReasons: rejectionReasons.sorted { $0.rawValue < $1.rawValue },
            warningFlags: warningFlags.sorted { $0.rawValue < $1.rawValue },
            baselineEstablished: false
        )
    }

    private func evaluateAttempt(
        _ attempt: NeutralCalibrationAttemptEvidence,
        maximumGap: TimeInterval
    ) -> (continuousTrackedDuration: TimeInterval, hardFailureCount: Int, rejectionReasons: Set<QCFlag>) {
        var firstTimestamp: TimeInterval?
        var previousTimestamp: TimeInterval?
        var hardFailureCount = 0
        var rejectionReasons: Set<QCFlag> = []

        for event in attempt.events {
            guard isTrustworthy(event) else {
                hardFailureCount += 1
                rejectionReasons.formUnion(reasons(for: event))
                continue
            }
            guard event.sourceTimestamp.isFinite else {
                hardFailureCount += 1
                rejectionReasons.insert(.invalidTimestampGap)
                continue
            }
            if let previousTimestamp {
                let interval = event.sourceTimestamp - previousTimestamp
                guard interval > 0, interval <= maximumGap else {
                    hardFailureCount += 1
                    rejectionReasons.insert(.invalidTimestampGap)
                    continue
                }
            } else {
                firstTimestamp = event.sourceTimestamp
            }
            previousTimestamp = event.sourceTimestamp
        }

        let duration = firstTimestamp.flatMap { first in
            previousTimestamp.map { max(0, $0 - first) }
        } ?? 0
        return (duration, hardFailureCount, rejectionReasons)
    }

    private func isTrustworthy(_ event: NeutralCalibrationEvent) -> Bool {
        event.faceTrackingState == .tracking &&
            event.faceIsPresent &&
            event.visibleFaceCount == 1 &&
            event.hasBlendshapeMeasurements &&
            !event.cameraTrackingState.localizedCaseInsensitiveContains("limited")
    }

    private func reasons(for event: NeutralCalibrationEvent) -> Set<QCFlag> {
        var reasons: Set<QCFlag> = []
        switch event.faceTrackingState {
        case .noFace:
            reasons.formUnion([.noFace, .trackingLost])
        case .multipleFaces:
            reasons.insert(.multipleFaces)
        case .tracking:
            break
        }
        if event.cameraTrackingState.localizedCaseInsensitiveContains("limited") {
            reasons.insert(.trackingLost)
        }
        if !event.hasBlendshapeMeasurements {
            reasons.insert(.missingBlendshapeValue)
        }
        return reasons
    }
}
