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
        Group {
            if viewModel.sessionFolders.isEmpty {
                ContentUnavailableView(
                    "No Previous Sessions",
                    systemImage: "tray",
                    description: Text("Completed local sessions will appear here.")
                )
            } else {
                List(viewModel.sessionFolders, id: \.self) { url in
                    NavigationLink(value: AppRoute.meshInspector(url)) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(.headline)
                            Text(url.deletingLastPathComponent().lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .faceworkScreenBackground()
        .navigationTitle("Previous Sessions")
        .onAppear {
            viewModel.loadSessions()
        }
    }
}
