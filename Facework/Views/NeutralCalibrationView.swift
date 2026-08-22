//
//  NeutralCalibrationView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct NeutralCalibrationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var taskVM = TaskExecutionViewModel()
    @State private var collectedFrames: [FrameCapture] = []
    @State private var secondsRemaining: Double = AppConfiguration.shared.neutralCaptureDuration
    @State private var calibrationPhase: NeutralCalibrationPhase = .ready
    @State private var observationCollector: FaceObservationCollector?
    @State private var captureTimer: Timer?
    @State private var calibrationMessage: String?
    @State private var attemptEvents: [NeutralCalibrationEvent] = []

    private var captureVM: CaptureSessionViewModel? { appState.currentSessionViewModel }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FaceworkSectionHeader("Neutral Calibration", subtitle: "Remain relaxed and face the camera.")

                if let vm = captureVM {
                    FaceTrackingViewRepresentable(trackingManager: vm.trackingManager)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    calibrationStatus

                    FaceworkCard {
                        HStack {
                            Text(phaseTitle)
                                .font(.headline)
                            Spacer()
                            Text("\(String(format: "%.1f", secondsRemaining)) s")
                                .font(.title2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    if let calibrationMessage {
                        FaceworkStatusBadge(
                            title: calibrationMessage,
                            systemImage: "arrow.clockwise.circle.fill",
                            color: .orange
                        )
                    }

                    HStack {
                        if calibrationPhase.showsRetryControl {
                            Button("Retry Calibration") {
                                reset()
                                beginCapture(with: vm)
                            }
                            .buttonStyle(FaceworkPrimaryButtonStyle())
                        } else {
                            Button {
                                beginCapture(with: vm)
                            } label: {
                                Text(primaryButtonTitle)
                                    .transaction { $0.animation = nil }
                            }
                            .buttonStyle(FaceworkPrimaryButtonStyle())
                            .disabled(calibrationPhase != .ready)
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
        .faceworkScreenBackground()
        .onAppear {
            captureVM?.startTracking()
        }
        .onDisappear {
            stopCapture()
            captureVM?.stopTracking()
        }
    }

    private func beginCapture(with vm: CaptureSessionViewModel) {
        stopCapture()
        calibrationPhase = .capturing
        calibrationMessage = nil
        taskVM.resetForNextRep()
        collectedFrames = []
        attemptEvents = []
        secondsRemaining = AppConfiguration.shared.neutralCaptureDuration

        let collector = FaceObservationCollector(
            provider: vm.trackingManager,
            cameraTrackingState: { vm.trackingManager.trackingStateDescription }
        )
        observationCollector = collector
        collector.start(mode: .neutral, eventHandler: { collectedObservation in
            let event = NeutralCalibrationEvent(collectedObservation: collectedObservation)
            attemptEvents.append(event)
            taskVM.receiveCalibrationEvent(collectedObservation)
        }) { collectedObservation in
            taskVM.appendLiveFrame(
                collectedObservation: collectedObservation,
                baseline: [:],
                isNeutralPhase: true,
                rawCaptureHandler: vm.recordMesh
            )
            collectedFrames = taskVM.captureFrames
        }

        let end = Date().addingTimeInterval(AppConfiguration.shared.neutralCaptureDuration)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            MainActor.assumeIsolated {
                let now = Date()
                secondsRemaining = max(0, end.timeIntervalSince(now))

                if now >= end {
                    timer.invalidate()
                    captureTimer = nil
                    observationCollector?.stop()
                    observationCollector = nil
                    calibrationPhase = .checking
                    let result = vm.updateBaseline(
                        frames: collectedFrames,
                        attempt: NeutralCalibrationAttemptEvidence(events: attemptEvents)
                    )
                    switch result {
                    case .success:
                        if let firstTask = vm.tasks.first {
                            appState.routeStack.append(.taskInstruction(firstTask))
                        }
                    case .failure(let reason, _):
                        calibrationPhase = .failed
                        calibrationMessage = message(for: reason)
                    }
                }
            }
        }
        captureTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func reset() {
        stopCapture()
        calibrationPhase = .ready
        collectedFrames.removeAll()
        attemptEvents.removeAll()
        taskVM.resetForNextRep()
        captureVM?.prepareCalibrationRetry()
        calibrationMessage = nil
        secondsRemaining = AppConfiguration.shared.neutralCaptureDuration
    }

    private func stopCapture() {
        observationCollector?.stop()
        observationCollector = nil
        captureTimer?.invalidate()
        captureTimer = nil
    }

    @ViewBuilder
    private var calibrationStatus: some View {
        switch taskVM.calibrationLiveStatus(phase: calibrationPhase) {
        case .noFace:
            FaceworkStatusBadge(title: "No face detected", systemImage: "person.crop.circle.badge.xmark", color: .red)
        case .multipleFaces:
            FaceworkStatusBadge(title: "Multiple faces detected", systemImage: "person.2.fill", color: .red)
        case .trackingInterrupted:
            FaceworkStatusBadge(title: "Tracking interrupted", systemImage: "exclamationmark.triangle.fill", color: .red)
        case .waiting:
            FaceworkStatusBadge(title: "Waiting for face", systemImage: "faceid", color: .secondary)
        case .passing:
            LiveQCIndicatorView(flags: taskVM.liveQCFlags, isValid: true)
        case .failing:
            LiveQCIndicatorView(flags: taskVM.liveQCFlags, isValid: false)
        }
    }

    private var phaseTitle: String {
        switch calibrationPhase {
        case .ready: "Ready to calibrate"
        case .capturing: "Calibration in progress"
        case .checking: "Checking calibration"
        case .failed: "Calibration needs another attempt"
        }
    }

    private var primaryButtonTitle: String {
        switch calibrationPhase {
        case .ready: "Start Baseline Capture"
        case .capturing: "Capturing..."
        case .checking: "Checking calibration..."
        case .failed: "Retry Calibration"
        }
    }

    private func message(for reason: NeutralCalibrationFailureReason) -> String {
        switch reason {
        case .noCapturedFrames:
            "Calibration needs another attempt. Make sure one face is visible."
        case .noEligibleFrames:
            "Tracking or positioning was interrupted. Please remain still and try again."
        case .trackingInterrupted:
            "Tracking was interrupted. Keep one face visible and try again."
        case .insufficientTrackedDuration:
            "Calibration needs another attempt. Keep your face visible for the full capture."
        }
    }
}
