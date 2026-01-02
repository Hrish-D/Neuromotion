//
//  ContentView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-28.
//

import SwiftUI
import SwiftData
import ARKit
import RealityKit

struct ContentView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \FaceMeasurement.timestamp, order: .reverse)
    private var measurements: [FaceMeasurement]

    @State private var latestMeasurement: FaceMeasurement?
    @State private var showCapture = false

    var body: some View {

        let smileSym = latestMeasurement?.smileSymmetry ?? 0
        let blinkSym = latestMeasurement?.blinkSymmetry ?? 0

        let interpretation = interpretSymmetry(Double(smileSym))

        VStack(spacing: 16) {

            Text("Neuromotion Analysis")
                .font(.title)
                .fontWeight(.bold)

            if let m = latestMeasurement {

                VStack(spacing: 6) {
                    Text("Smile Symmetry: \(Int(m.smileSymmetry * 100))%")
                    Text("Blink Symmetry: \(Int(m.blinkSymmetry * 100))%")
                }
                .font(.headline)
                .foregroundColor(interpretation.color)

                Text(interpretation.label)
                    .foregroundColor(interpretation.color)

                Divider()

                SymmetryBarView(title: "Left Smile", value: Double(m.smileLeft))
                SymmetryBarView(title: "Right Smile", value: Double(m.smileRight))

                Divider()
            } else {
                Text("No scan yet")
                    .foregroundColor(.secondary)
            }

            Divider()

            Text("Previous Scans")
                .font(.headline)

            ForEach(measurements.prefix(5)) { m in
                VStack(alignment: .leading) {
                    Text(m.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Smile: \(Int(m.smileSymmetry * 100))%  |  Blink: \(Int(m.blinkSymmetry * 100))%")
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Spacer()

            Button("Start Face Scan") {
                showCapture = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $showCapture) {
            FaceCaptureView { measurement in
                context.insert(measurement)
                latestMeasurement = measurement
            }
        }
    }
}
