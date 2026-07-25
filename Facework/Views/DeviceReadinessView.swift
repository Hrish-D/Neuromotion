//
//  DeviceReadinessView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI
import ARKit
import AVFoundation

struct DeviceReadinessView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let vm = appState.currentSessionViewModel {
            DeviceReadinessContent(vm: vm)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("Device Readiness")
                    .font(.title2)
                    .bold()

                Text("No active capture session was found.")
                    .foregroundStyle(.red)

                Button("Go Back") {
                    appState.routeStack.removeLast()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
        }
    }
}

private struct DeviceReadinessContent: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var vm: CaptureSessionViewModel

    @State private var hasRequested = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Readiness")
                .font(.title2)
                .bold()

            readinessRow("Face Tracking Supported", vm.readinessStatus.isFaceTrackingSupported)
            readinessRow("Camera Permission", vm.readinessStatus.cameraPermissionGranted)
            readinessRow("Front Camera", vm.readinessStatus.frontCameraAvailable)
            readinessRow("Exactly One Face", vm.readinessStatus.exactlyOneFaceVisible)
            readinessRow("Framing Ready", vm.readinessStatus.framingReady)
            readinessRow("Pose Ready", vm.readinessStatus.poseReady)
            readinessRow("Tracking Stable", vm.readinessStatus.trackingStable)

            if !vm.readinessStatus.blockingReasons.isEmpty {
                Text("Blocking Reasons")
                    .font(.headline)

                ForEach(vm.readinessStatus.blockingReasons, id: \.self) { reason in
                    Text("• \(reason)")
                        .foregroundStyle(.red)
                }
            }

            Button("Proceed to Neutral Baseline") {
                vm.trackingManager.stop()
                appState.routeStack.append(.neutralCalibration)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.readinessStatus.canProceed)

            Spacer()
        }
        .padding()
        .onAppear {
            runReadinessChecks()
        }
    }

    private func runReadinessChecks() {
        guard !hasRequested else { return }
        hasRequested = true

        let faceTrackingSupported = ARFaceTrackingConfiguration.isSupported
        let frontCameraAvailable = AVCaptureDevice.default(
            .builtInTrueDepthCamera,
            for: .video,
            position: .front
        ) != nil

        vm.readinessStatus.isFaceTrackingSupported = faceTrackingSupported
        vm.readinessStatus.frontCameraAvailable = frontCameraAvailable

        vm.trackingManager.requestCameraPermission { granted in
            DispatchQueue.main.async {
                vm.readinessStatus.cameraPermissionGranted = granted

                if granted && faceTrackingSupported && frontCameraAvailable {
                    vm.trackingManager.start()

                    vm.readinessStatus.exactlyOneFaceVisible = true
                    vm.readinessStatus.framingReady = true
                    vm.readinessStatus.poseReady = true
                    vm.readinessStatus.trackingStable = true
                    vm.readinessStatus.blockingReasons = []
                } else {
                    vm.readinessStatus.exactlyOneFaceVisible = false
                    vm.readinessStatus.framingReady = false
                    vm.readinessStatus.poseReady = false
                    vm.readinessStatus.trackingStable = false

                    var reasons: [String] = []

                    if !faceTrackingSupported {
                        reasons.append("Face tracking is not supported on this device.")
                    }

                    if !frontCameraAvailable {
                        reasons.append("A TrueDepth front camera was not found.")
                    }

                    if !granted {
                        reasons.append("Camera permission was denied.")
                    }

                    vm.readinessStatus.blockingReasons = reasons
                }
            }
        }
    }

    private func readinessRow(_ title: String, _ passed: Bool) -> some View {
        HStack {
            Text(title)

            Spacer()

            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(passed ? .green : .red)
        }
    }
}
