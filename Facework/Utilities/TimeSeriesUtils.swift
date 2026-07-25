//
//  TimeSeriesUtils.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

enum TimeSeriesUtils {
    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    static func linearSlope(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }

        let xMean = mean(x)
        let yMean = mean(y)

        let numerator = zip(x, y)
            .map { ($0 - xMean) * ($1 - yMean) }
            .reduce(0, +)

        let denominator = x
            .map { pow($0 - xMean, 2) }
            .reduce(0, +)

        guard denominator != 0 else { return 0 }
        return numerator / denominator
    }
    
    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let avg = mean(values)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }

    static func coefficientOfVariation(_ values: [Double]) -> Double {
        let avg = mean(values)
        guard abs(avg) > 0.000001 else { return 0 }
        return standardDeviation(values) / abs(avg)
    }

    static func slope(_ values: [Double]) -> Double {
        linearSlope(values)
    }

    static func linearSlope(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let x = values.indices.map { Double($0) }
        let xMean = mean(x)
        let yMean = mean(values)

        let numerator = zip(x, values)
            .map { ($0 - xMean) * ($1 - yMean) }
            .reduce(0, +)

        let denominator = x
            .map { pow($0 - xMean, 2) }
            .reduce(0, +)

        guard denominator != 0 else { return 0 }
        return numerator / denominator
    }

    static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        movingAverage(values: values, window: window)
    }

    static func movingAverage(values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count >= window else { return values }

        return values.indices.map { index in
            let start = max(0, index - window + 1)
            let slice = values[start...index]
            return mean(Array(slice))
        }
    }
}
