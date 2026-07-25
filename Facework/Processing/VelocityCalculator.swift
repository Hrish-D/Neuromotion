//
//  VelocityCalculator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct VelocityCalculator {
    func derivative(values: [Double], timestamps: [TimeInterval]) -> [Double] {
        guard values.count == timestamps.count, values.count > 1 else { return [] }
        var output: [Double] = [0]
        for index in 1..<values.count {
            let dt = timestamps[index] - timestamps[index - 1]
            guard dt > 0 else {
                output.append(0)
                continue
            }
            output.append((values[index] - values[index - 1]) / dt)
        }
        return output
    }

    func peakVelocity(values: [Double], timestamps: [TimeInterval]) -> Double? {
        derivative(values: values, timestamps: timestamps).max()
    }

    func meanActiveVelocity(values: [Double], timestamps: [TimeInterval], activeIndices: [Int]) -> Double? {
        let derivatives = derivative(values: values, timestamps: timestamps)
        let selected = activeIndices.compactMap { index -> Double? in
            guard derivatives.indices.contains(index) else { return nil }
            return derivatives[index]
        }
        guard !selected.isEmpty else { return nil }
        return selected.reduce(0, +) / Double(selected.count)
    }
}
