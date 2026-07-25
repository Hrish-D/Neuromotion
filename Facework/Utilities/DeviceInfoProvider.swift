//
//  DeviceInfoProvider.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import UIKit

struct DeviceInfoProvider {
    static func deviceModel() -> String {
        UIDevice.current.model
    }

    static func osVersion() -> String {
        UIDevice.current.systemVersion
    }
}
