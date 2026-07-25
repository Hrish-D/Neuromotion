//
//  PreviousSessionsView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI

struct PreviousSessionsView: View {
    @StateObject private var viewModel = PreviousSessionsViewModel()

    var body: some View {
        List(viewModel.sessionFolders, id: \.self) { url in
            VStack(alignment: .leading) {
                Text(url.lastPathComponent)
                    .font(.headline)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Previous Sessions")
        .onAppear {
            viewModel.loadSessions()
        }
    }
}
