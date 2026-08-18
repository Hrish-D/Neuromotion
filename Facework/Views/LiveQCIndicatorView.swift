//
//  LiveQCIndicatorView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct LiveQCIndicatorView: View {
    let flags: [QCFlag]
    let isValid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FaceworkStatusBadge(
                    title: isValid ? "QC Passing" : "QC Failing",
                    systemImage: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    color: isValid ? .green : .red
                )
                Spacer()
            }
            if !flags.isEmpty {
                ForEach(flags) { flag in
                    Text(flag.rawValue)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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
