//
//  FaceMeasurement.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-28.
//

import Foundation
import SwiftData

@Model
class FaceMeasurement {
    var timestamp: Date

    var smileLeft: Float
    var smileRight: Float

    var blinkLeft: Float
    var blinkRight: Float

    var smileSymmetry: Float
    var blinkSymmetry: Float

    init(
        timestamp: Date,
        smileLeft: Float,
        smileRight: Float,
        blinkLeft: Float,
        blinkRight: Float,
        smileSymmetry: Float,
        blinkSymmetry: Float
    ) {
        self.timestamp = timestamp
        self.smileLeft = smileLeft
        self.smileRight = smileRight
        self.blinkLeft = blinkLeft
        self.blinkRight = blinkRight
        self.smileSymmetry = smileSymmetry
        self.blinkSymmetry = blinkSymmetry
    }
}

