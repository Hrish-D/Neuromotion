//
//  DeviceInfoProvider.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import UIKit

struct DeviceInformation: Codable, Equatable {
    let modelIdentifier: String
    let operatingSystemName: String
    let operatingSystemVersion: String
}

struct DeviceInfoProvider {
    static func current(device: UIDevice = .current) -> DeviceInformation {
        DeviceInformation(
            modelIdentifier: hardwareModelIdentifier(),
            operatingSystemName: device.systemName,
            operatingSystemVersion: device.systemVersion
        )
    }

    private static func hardwareModelIdentifier() -> String {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return "unknown-device" }

        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
