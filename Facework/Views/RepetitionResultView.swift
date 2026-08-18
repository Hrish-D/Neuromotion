//
//  RepetitionResultView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct RepetitionResultView: View {
    let result: RepetitionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaceworkStatusBadge(
                title: result.valid ? "Valid Repetition" : (result.partial ? "Partial Repetition" : "Invalid Repetition"),
                systemImage: result.valid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                color: result.valid ? .green : (result.partial ? .orange : .red)
            )
            Text("QC pass rate: \(result.qcSummary.percentFramesPassing * 100, specifier: "%.0f")%")
            if let symmetry = result.derivedMetrics.symmetry {
                Text("Symmetry: \(symmetry, specifier: "%.3f")")
            }
            if let ampL = result.derivedMetrics.peakAmplitudeLeft {
                Text("Peak amplitude left: \(ampL, specifier: "%.3f")")
            }
            if let ampR = result.derivedMetrics.peakAmplitudeRight {
                Text("Peak amplitude right: \(ampR, specifier: "%.3f")")
            }
            if let failure = result.failureReason, !failure.isEmpty {
                Text("Failure reason: \(failure)")
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
    }
}
