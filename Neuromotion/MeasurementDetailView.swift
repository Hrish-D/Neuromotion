//
//  MeasurementDetailView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-28.
//

import Foundation
import SwiftUI

struct MeasurementDetailView: View {

    let measurement: FaceMeasurement

    var body: some View {
        Form {
            Section("Smile") {
                Text("Left: \(measurement.smileLeft, specifier: "%.2f")")
                Text("Right: \(measurement.smileRight, specifier: "%.2f")")
                Text("Symmetry: \(measurement.smileSymmetry, specifier: "%.2f")")
            }

            Section("Blink") {
                Text("Left: \(measurement.blinkLeft, specifier: "%.2f")")
                Text("Right: \(measurement.blinkRight, specifier: "%.2f")")
                Text("Symmetry: \(measurement.blinkSymmetry, specifier: "%.2f")")
            }

            Section("Session") {
                Text(measurement.timestamp.formatted())
            }
        }
        .navigationTitle("Measurement")
    }
}
