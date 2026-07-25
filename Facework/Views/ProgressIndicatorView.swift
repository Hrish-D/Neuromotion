//
//  ProgressIndicatorView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct ProgressIndicatorView: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("Repetition \(current) of \(total)")
                .font(.headline)
            ProgressView(value: Double(current - 1), total: Double(max(total, 1)))
        }
    }
}
