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
                Circle()
                    .fill(isValid ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(isValid ? "QC Passing" : "QC Failing")
                    .font(.headline)
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
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
