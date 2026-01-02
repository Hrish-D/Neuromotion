//
//  SymmetryBarView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-30.
//

import Foundation
import SwiftUI

struct SymmetryBarView: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            Text("\(title): \(Int(value * 100))%")
                .font(.subheadline)

            ProgressView(value: value)
                .tint(
                    value > 0.85 ? .green :
                    value > 0.75 ? .yellow :
                    value > 0.6  ? .orange : .red
                )
        }
    }
}
