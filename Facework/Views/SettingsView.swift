//
//  SettingsView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Mode") {
                Toggle("Research / Debug Mode", isOn: $appState.researchMode)
                Text("When enabled, the app shows raw blendshapes, QC reasons, thresholds, and debug-oriented outputs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Save Validation Images", isOn: $appState.saveValidationImages)
                Text("When enabled, each sampled motion frame is saved as a JPEG and linked from the frame CSV/JSON export.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Show Live Face Mesh", isOn: $appState.showFaceMeshOverlay)
                Text("When enabled, ARKit's face geometry is drawn over the camera preview during motion tasks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Threshold Summary") {
                Text("Yaw threshold: \(AppConfiguration.shared.yawThresholdDegrees, specifier: "%.0f")°")
                Text("Pitch threshold: \(AppConfiguration.shared.pitchThresholdDegrees, specifier: "%.0f")°")
                Text("Roll threshold: \(AppConfiguration.shared.rollThresholdDegrees, specifier: "%.0f")°")
                Text("Minimum valid frame percentage: \(AppConfiguration.shared.minimumValidFramePercentage * 100, specifier: "%.0f")%")
                Text("Smoothing window: \(AppConfiguration.shared.smoothingWindow)")
            }
        }
        .navigationTitle("Settings")
    }
}
