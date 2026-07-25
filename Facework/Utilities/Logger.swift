//
//  Logger.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

final class Logger {
    static let shared = Logger()
    private let queue = DispatchQueue(label: "logger.queue")

    func log(_ message: String) {
        queue.async {
            print("[FacialMotionBaselineApp] \(message)")
        }
    }
}
