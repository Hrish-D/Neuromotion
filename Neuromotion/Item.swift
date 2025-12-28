//
//  Item.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-28.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
