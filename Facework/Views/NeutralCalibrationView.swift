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
    @State private var captureStarted = false
    @State private var observationCollector: FaceObservationCollector?
    @State private var captureTimer: Timer?

    private var captureVM: CaptureSessionViewModel? { appState.currentSessionViewModel }

    var body: some View {
        VStack(spacing: 16) {
            Text("Neutral Baseline")
                .font(.title2)
                .bold()
            Text("Relax your face, keep your eyes open, and keep your mouth relaxed.")
                .multilineTextAlignment(.center)

            if let vm = captureVM {
                FaceTrackingViewRepresentable(trackingManager: vm.trackingManager)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                LiveQCIndicatorView(flags: taskVM.liveQCFlags, isValid: taskVM.liveIsValid)
                Text("Countdown: \(String(format: "%.1f", secondsRemaining)) s")
                    .font(.headline)

                HStack {
                    Button(captureStarted ? "Capturing..." : "Start Baseline Capture") {
                        beginCapture(with: vm)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(captureStarted)

                    Button("Retry") {
                        reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            captureVM?.startTracking()
        }
        .onDisappear {
            stopCapture()
            captureVM?.stopTracking()
        }
    }

    private func beginCapture(with vm: CaptureSessionViewModel) {
        captureStarted = true
        taskVM.resetForNextRep()
        collectedFrames = []
        secondsRemaining = AppConfiguration.shared.neutralCaptureDuration

        let collector = FaceObservationCollector(
            provider: vm.trackingManager,
            cameraTrackingState: { vm.trackingManager.trackingStateDescription }
        )
        observationCollector = collector
        collector.start(mode: .neutral) { collectedObservation in
            taskVM.appendLiveFrame(
                collectedObservation: collectedObservation,
                baseline: [:],
                isNeutralPhase: true
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
                    vm.updateBaseline(frames: collectedFrames)
                    appState.routeStack.append(.taskInstruction(vm.tasks.first!))
                }
            }
        }
        captureTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func reset() {
        stopCapture()
        captureStarted = false
        collectedFrames.removeAll()
        taskVM.resetForNextRep()
        secondsRemaining = AppConfiguration.shared.neutralCaptureDuration
    }

    private func stopCapture() {
        observationCollector?.stop()
        observationCollector = nil
        captureTimer?.invalidate()
        captureTimer = nil
    }
}
