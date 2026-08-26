//
//  TaskExecutionView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct TaskExecutionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var taskVM = TaskExecutionViewModel()
    @State private var isCapturing = false
    @State private var holdCountdown: Double = 0
    @State private var latestResult: RepetitionResult?
    @State private var observationCollector: FaceObservationCollector?
    @State private var captureTimer: Timer?
    
    let task: TaskType

    private var captureVM: CaptureSessionViewModel? { appState.currentSessionViewModel }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FaceworkSectionHeader(task.displayName, subtitle: "Complete each repetition steadily and comfortably.")
                
                if let vm = captureVM {
                    FaceTrackingViewRepresentable(
                        trackingManager: vm.trackingManager,
                        showMeshOverlay: appState.showFaceMeshOverlay
                    )
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    Toggle("Show live face mesh", isOn: $appState.showFaceMeshOverlay)
                        .font(.subheadline)

                    FaceworkCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ProgressIndicatorView(current: taskVM.currentRepetitionIndex,
                                                  total: vm.taskConfigurations[task]?.repetitionsRequired ?? 3)
                            HStack {
                                Text(isCapturing ? "Hold" : "Ready")
                                    .font(.headline)
                                Spacer()
                                Text("\(holdCountdown, specifier: "%.1f") s")
                                    .font(.title2.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }

                    LiveQCIndicatorView(flags: taskVM.liveQCFlags, isValid: taskVM.liveIsValid)

                    if appState.researchMode {
                        debugSection
                    }

                    HStack {
                        Button {
                            startCapture(using: vm)
                        } label: {
                            Text(isCapturing ? "Capturing..." : "Capture Repetition")
                                .transaction { $0.animation = nil }
                        }
                        .buttonStyle(FaceworkPrimaryButtonStyle())
                        .disabled(isCapturing)

                        Button("Reset Rep") {
                            stopCapture()
                            isCapturing = false
                            taskVM.resetForNextRep()
                            latestResult = nil
                        }
                        .buttonStyle(FaceworkSecondaryButtonStyle())
                    }

                    if let latestResult {
                        RepetitionResultView(result: latestResult)
                    }
                }
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

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Research / Debug")
                .font(.headline)
            Text("Raw blendshapes captured: \(taskVM.debugValues.count)")
            ForEach(taskVM.debugValues.keys.sorted().prefix(8), id: \.self) { key in
                HStack {
                    Text(key)
                    Spacer()
                    Text(String(format: "%.3f", taskVM.debugValues[key] ?? 0))
                    Text("→")
                    Text(String(format: "%.3f", taskVM.normalizedValues[key] ?? 0))
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func startCapture(using vm: CaptureSessionViewModel) {
        guard let config = vm.taskConfigurations[task] else { return }
        isCapturing = true
        latestResult = nil
        holdCountdown = config.holdDuration
        let repIndex = taskVM.currentRepetitionIndex
        let start = Date()
        let end = start.addingTimeInterval(config.holdDuration + 1.0)
        let sessionFolder = (try? FileManagerService().sessionFolder(participantID: vm.metadata.participantID,
                                                                     sessionID: vm.metadata.sessionID)) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let collector = FaceObservationCollector(
            provider: vm.trackingManager,
            cameraTrackingState: { vm.trackingManager.trackingStateDescription }
        )
        observationCollector = collector
        collector.start(mode: .task(task: task, repetitionIndex: repIndex)) { collectedObservation in
            let nextFrameIndex = taskVM.nextFrameIndex
            let validationImageAssociation: ValidationImageAssociation?

            let shouldSaveValidationImage = appState.saveValidationImages &&
                                            ValidationImageCapturePolicy.shouldCapture(
                                                acceptedFrameIndex: nextFrameIndex
                                            )

            if shouldSaveValidationImage {
                let imageName = ValidationImageCapturePolicy.fileStem(
                    task: task,
                    repetitionIndex: repIndex,
                    frameIndex: nextFrameIndex
                )
                let overlay = "\(task.displayName) | rep \(repIndex) | frame \(nextFrameIndex)"
                if let imageSource = collectedObservation.validationImageSource {
                    validationImageAssociation = vm.imageCaptureService.saveValidationImage(
                        from: imageSource,
                        named: imageName,
                        in: sessionFolder,
                        overlayText: overlay
                    )
                } else {
                    validationImageAssociation = ValidationImageAssociation(
                        reference: nil,
                        imageSourceTimestamp: nil,
                        synchronizationStatus: .unavailable
                    )
                }
            } else {
                validationImageAssociation = nil
            }

            taskVM.appendLiveFrame(
                collectedObservation: collectedObservation,
                baseline: vm.baselineValues,
                isNeutralPhase: false,
                validationImageAssociation: validationImageAssociation,
                rawCaptureHandler: vm.recordMesh
            )
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            MainActor.assumeIsolated {
                let now = Date()
                holdCountdown = max(0, end.timeIntervalSince(now) - 1.0)

                if now >= end {
                    timer.invalidate()
                    captureTimer = nil
                    observationCollector?.stop()
                    let peakCandidate = taskVM.peakFrameCandidate(for: task)
                    let framesForRep = taskVM.captureFrames
                    let result = taskVM.finalize(task: task,
                                                 config: config,
                                                 peakFrameReference: peakCandidate?.frame.imageReference,
                                                 peakFrameIndex: peakCandidate?.frame.frameIndex,
                                                 peakFrameTimestamp: peakCandidate?.frame.timestamp,
                                                 peakSignalValue: peakCandidate?.signalValue)
                    latestResult = result
                    vm.store(repetition: result, frames: framesForRep)

                    if repIndex >= config.repetitionsRequired {
                        if vm.currentTaskIndex >= vm.tasks.count - 1 {
                            _ = vm.saveSession()
                            appState.routeStack.append(.sessionSummary)
                        } else {
                            vm.moveToNextTask()
                            if let next = vm.currentTask {
                                appState.routeStack.append(.taskInstruction(next))
                            }
                        }
                    } else {
                        let nextRepIndex = repIndex + 1
                        taskVM.resetForNextRep()
                        taskVM.currentRepetitionIndex = nextRepIndex
                    }

                    isCapturing = false
                }
            }
        }
        captureTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func stopCapture() {
        observationCollector?.stop()
        observationCollector = nil
        captureTimer?.invalidate()
        captureTimer = nil
    }
}
