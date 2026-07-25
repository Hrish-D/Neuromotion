//
//  SymmetryCalculator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct SymmetryCalculator {
    func symmetry(left: Double?, right: Double?) -> Double? {
        guard let left, let right else { return nil }
        let denominator = max(abs(left), abs(right), 0.000001)
        return max(0, 1 - abs(left - right) / denominator)
    }
}
