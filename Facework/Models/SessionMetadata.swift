//
//  SessionMetadata.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct SessionMetadata: Codable, Equatable {
    let sessionID: String
    let studyID: String
    let participantID: String
    let raterID: String?
    let appVersion: String
    let deviceModel: String
    let osVersion: String
    let sessionDate: Date
    let notes: String?
    let affectedSide: AffectedSide
    let sessionLabel: String?

    let appMarketingVersion: String
    let appBuildNumber: String
    let rawDataSchemaVersion: String
    let analysisAlgorithmVersion: String
    let captureProtocolVersion: String
    let meshCaptureVersion: String
    let landmarkConfigurationVersion: String
    let deviceModelIdentifier: String
    let operatingSystemName: String
    let operatingSystemVersion: String

    let wasLoadedFromLegacySchema: Bool

    init(
        sessionID: String,
        studyID: String,
        participantID: String,
        raterID: String?,
        appVersion: String,
        deviceModel: String,
        osVersion: String,
        sessionDate: Date,
        notes: String?,
        affectedSide: AffectedSide,
        sessionLabel: String?,
        appMarketingVersion: String,
        appBuildNumber: String,
        rawDataSchemaVersion: String,
        analysisAlgorithmVersion: String,
        captureProtocolVersion: String,
        meshCaptureVersion: String,
        landmarkConfigurationVersion: String,
        deviceModelIdentifier: String,
        operatingSystemName: String,
        operatingSystemVersion: String,
        wasLoadedFromLegacySchema: Bool = false
    ) {
        self.sessionID = sessionID
        self.studyID = studyID
        self.participantID = participantID
        self.raterID = raterID
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.sessionDate = sessionDate
        self.notes = notes
        self.affectedSide = affectedSide
        self.sessionLabel = sessionLabel
        self.appMarketingVersion = appMarketingVersion
        self.appBuildNumber = appBuildNumber
        self.rawDataSchemaVersion = rawDataSchemaVersion
        self.analysisAlgorithmVersion = analysisAlgorithmVersion
        self.captureProtocolVersion = captureProtocolVersion
        self.meshCaptureVersion = meshCaptureVersion
        self.landmarkConfigurationVersion = landmarkConfigurationVersion
        self.deviceModelIdentifier = deviceModelIdentifier
        self.operatingSystemName = operatingSystemName
        self.operatingSystemVersion = operatingSystemVersion
        self.wasLoadedFromLegacySchema = wasLoadedFromLegacySchema
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID
        case studyID
        case participantID
        case raterID
        case appVersion
        case deviceModel
        case osVersion
        case sessionDate
        case notes
        case affectedSide
        case sessionLabel
        case appMarketingVersion
        case appBuildNumber
        case rawDataSchemaVersion
        case analysisAlgorithmVersion
        case captureProtocolVersion
        case meshCaptureVersion
        case landmarkConfigurationVersion
        case deviceModelIdentifier
        case operatingSystemName
        case operatingSystemVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionID = try container.decode(String.self, forKey: .sessionID)
        studyID = try container.decode(String.self, forKey: .studyID)
        participantID = try container.decode(String.self, forKey: .participantID)
        raterID = try container.decodeIfPresent(String.self, forKey: .raterID)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        deviceModel = try container.decode(String.self, forKey: .deviceModel)
        osVersion = try container.decode(String.self, forKey: .osVersion)
        sessionDate = try container.decode(Date.self, forKey: .sessionDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        affectedSide = try container.decode(AffectedSide.self, forKey: .affectedSide)
        sessionLabel = try container.decodeIfPresent(String.self, forKey: .sessionLabel)

        let hasCurrentSchema = container.contains(.rawDataSchemaVersion)
        appMarketingVersion = try container.decodeIfPresent(
            String.self, forKey: .appMarketingVersion
        ) ?? "legacy-unknown"
        appBuildNumber = try container.decodeIfPresent(
            String.self, forKey: .appBuildNumber
        ) ?? "legacy-unknown"
        rawDataSchemaVersion = try container.decodeIfPresent(
            String.self, forKey: .rawDataSchemaVersion
        ) ?? "legacy-unknown"
        analysisAlgorithmVersion = try container.decodeIfPresent(
            String.self, forKey: .analysisAlgorithmVersion
        ) ?? "legacy-unknown"
        captureProtocolVersion = try container.decodeIfPresent(
            String.self, forKey: .captureProtocolVersion
        ) ?? "legacy-unknown"
        meshCaptureVersion = try container.decodeIfPresent(
            String.self, forKey: .meshCaptureVersion
        ) ?? "not-active"
        landmarkConfigurationVersion = try container.decodeIfPresent(
            String.self, forKey: .landmarkConfigurationVersion
        ) ?? "not-active"
        deviceModelIdentifier = try container.decodeIfPresent(
            String.self, forKey: .deviceModelIdentifier
        ) ?? "not-recorded"
        operatingSystemName = try container.decodeIfPresent(
            String.self, forKey: .operatingSystemName
        ) ?? "not-recorded"
        operatingSystemVersion = try container.decodeIfPresent(
            String.self, forKey: .operatingSystemVersion
        ) ?? "not-recorded"
        wasLoadedFromLegacySchema = !hasCurrentSchema
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(studyID, forKey: .studyID)
        try container.encode(participantID, forKey: .participantID)
        try container.encodeIfPresent(raterID, forKey: .raterID)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(deviceModel, forKey: .deviceModel)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(sessionDate, forKey: .sessionDate)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(affectedSide, forKey: .affectedSide)
        try container.encodeIfPresent(sessionLabel, forKey: .sessionLabel)
        try container.encode(appMarketingVersion, forKey: .appMarketingVersion)
        try container.encode(appBuildNumber, forKey: .appBuildNumber)
        try container.encode(rawDataSchemaVersion, forKey: .rawDataSchemaVersion)
        try container.encode(analysisAlgorithmVersion, forKey: .analysisAlgorithmVersion)
        try container.encode(captureProtocolVersion, forKey: .captureProtocolVersion)
        try container.encode(meshCaptureVersion, forKey: .meshCaptureVersion)
        try container.encode(landmarkConfigurationVersion, forKey: .landmarkConfigurationVersion)
        try container.encode(deviceModelIdentifier, forKey: .deviceModelIdentifier)
        try container.encode(operatingSystemName, forKey: .operatingSystemName)
        try container.encode(operatingSystemVersion, forKey: .operatingSystemVersion)
    }
}

enum AffectedSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    case bilateral
    case none

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}
