//
//  SymmetryInterpreter.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-30.
//

import Foundation
import SwiftUI

struct SymmetryInterpretation {
    let label: String
    let color: Color
}

func interpretSymmetry(_ score: Double) -> SymmetryInterpretation {
    switch score {
    case 0.9...1.0:
        return SymmetryInterpretation(label: "Near-symmetric", color: .green)
    case 0.75..<0.9:
        return SymmetryInterpretation(label: "Mild asymmetry", color: .yellow)
    case 0.6..<0.75:
        return SymmetryInterpretation(label: "Moderate asymmetry", color: .orange)
    default:
        return SymmetryInterpretation(label: "Severe asymmetry", color: .red)
    }
}
