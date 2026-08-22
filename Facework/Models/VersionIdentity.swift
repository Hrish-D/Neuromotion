import Foundation

struct AppBuildInformation: Codable, Equatable {
    static let unknownMarketingVersion = "unknown-version"
    static let unknownBuildNumber = "unknown-build"

    let marketingVersion: String
    let buildNumber: String

    var displayVersion: String {
        "\(marketingVersion) (\(buildNumber))"
    }

    static func current(bundle: Bundle = .main) -> AppBuildInformation {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

    static func from(infoDictionary: [String: Any]) -> AppBuildInformation {
        AppBuildInformation(
            marketingVersion: nonemptyString(
                infoDictionary["CFBundleShortVersionString"],
                fallback: unknownMarketingVersion
            ),
            buildNumber: nonemptyString(
                infoDictionary["CFBundleVersion"],
                fallback: unknownBuildNumber
            )
        )
    }

    private static func nonemptyString(_ value: Any?, fallback: String) -> String {
        guard let string = value as? String,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return string
    }
}

struct ResearchDataVersions: Codable, Equatable {
    let rawDataSchemaVersion: String
    let analysisAlgorithmVersion: String
    let captureProtocolVersion: String
    let meshCaptureVersion: String
    let landmarkConfigurationVersion: String

    static let current = ResearchDataVersions(
        rawDataSchemaVersion: "4.0.0",
        analysisAlgorithmVersion: "0.3.0",
        captureProtocolVersion: "0.4.0",
        meshCaptureVersion: "1.0.0",
        landmarkConfigurationVersion: "not-active"
    )
}

struct SessionMetadataFactory {
    let buildInformation: AppBuildInformation
    let researchDataVersions: ResearchDataVersions
    let deviceInformation: DeviceInformation

    static func current() -> SessionMetadataFactory {
        SessionMetadataFactory(
            buildInformation: .current(),
            researchDataVersions: .current,
            deviceInformation: DeviceInfoProvider.current()
        )
    }

    func make(
        sessionID: String,
        studyID: String,
        participantID: String,
        raterID: String?,
        sessionDate: Date,
        notes: String?,
        affectedSide: AffectedSide,
        sessionLabel: String?
    ) -> SessionMetadata {
        SessionMetadata(
            sessionID: sessionID,
            studyID: studyID,
            participantID: participantID,
            raterID: raterID,
            appVersion: buildInformation.marketingVersion,
            deviceModel: deviceInformation.modelIdentifier,
            osVersion: deviceInformation.operatingSystemVersion,
            sessionDate: sessionDate,
            notes: notes,
            affectedSide: affectedSide,
            sessionLabel: sessionLabel,
            appMarketingVersion: buildInformation.marketingVersion,
            appBuildNumber: buildInformation.buildNumber,
            rawDataSchemaVersion: researchDataVersions.rawDataSchemaVersion,
            analysisAlgorithmVersion: researchDataVersions.analysisAlgorithmVersion,
            captureProtocolVersion: researchDataVersions.captureProtocolVersion,
            meshCaptureVersion: researchDataVersions.meshCaptureVersion,
            landmarkConfigurationVersion: researchDataVersions.landmarkConfigurationVersion,
            deviceModelIdentifier: deviceInformation.modelIdentifier,
            operatingSystemName: deviceInformation.operatingSystemName,
            operatingSystemVersion: deviceInformation.operatingSystemVersion
        )
    }
}
