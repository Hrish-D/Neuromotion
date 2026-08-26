//
//  Untitled.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI
import Combine

@main
struct FacialMotionBaselineApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
        }
    }
}

final class AppState: ObservableObject {
    @Published var routeStack: [AppRoute] = []
    @Published var currentSessionViewModel: CaptureSessionViewModel?
    @Published var researchMode: Bool = AppConfiguration.shared.researchModeDefault
    
    @Published var saveValidationImages: Bool = true
    @Published var showFaceMeshOverlay: Bool = false
}
