import Foundation

// MARK: - Part 9 & Part 12: Versioned Configuration & Profile Persistence with Validation

public struct PersistedConfigurationBundle: Codable, Sendable, Equatable {
    public var schemaVersion: Int = 2
    public var exportedAt: Date = Date()
    public var config: AcousticClassifierConfig
    public var globalMappings: [AcousticGestureType: SystemActionType]
    public var appProfiles: [AppGestureProfile]

    public init(
        schemaVersion: Int = 2,
        exportedAt: Date = Date(),
        config: AcousticClassifierConfig = AcousticClassifierConfig(),
        globalMappings: [AcousticGestureType: SystemActionType] = Self.defaultGlobalMappings,
        appProfiles: [AppGestureProfile] = Self.defaultAppProfiles
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.config = config
        self.globalMappings = globalMappings
        self.appProfiles = appProfiles
    }

    public static var defaultGlobalMappings: [AcousticGestureType: SystemActionType] {
        [
            .doubleKnock: .playPauseMedia,
            .tripleKnock: .lockScreen,
            .doubleSnap: .muteUnmuteAudio,
            .knockPlusSnap: .privacyShield,
            .trackpadHoldDoubleKnock: .openSpotlight,
            .secretRhythm: .openChatGPT,
            .leftZoneDoubleKnock: .previousTrack,
            .rightZoneDoubleKnock: .nextTrack,
            .hingeNudge: .missionControl
        ]
    }

    public static var defaultAppProfiles: [AppGestureProfile] {
        [
            AppGestureProfile(
                id: "com.apple.Music",
                displayName: "Apple Music",
                bundleIdentifier: "com.apple.Music",
                isEnabled: true,
                mappings: [
                    .doubleKnock: .playPauseMedia,
                    .doubleSnap: .nextTrack,
                    .tripleKnock: .previousTrack
                ]
            ),
            AppGestureProfile(
                id: "com.spotify.client",
                displayName: "Spotify",
                bundleIdentifier: "com.spotify.client",
                isEnabled: true,
                mappings: [
                    .doubleKnock: .playPauseMedia,
                    .doubleSnap: .nextTrack,
                    .tripleKnock: .previousTrack
                ]
            ),
            AppGestureProfile(
                id: "us.zoom.xos",
                displayName: "Zoom Meetings",
                bundleIdentifier: "us.zoom.xos",
                isEnabled: true,
                mappings: [
                    .doubleKnock: .muteUnmuteAudio,
                    .tripleKnock: .privacyShield
                ]
            )
        ]
    }
}

public enum ConfigurationStore {
    private static let storageKey = "com.carelessdept.Reson.configuration.v3"

    public static func load(from defaults: UserDefaults = .standard) -> (bundle: PersistedConfigurationBundle, warnings: [String]) {
        guard let data = defaults.data(forKey: storageKey) else {
            return (PersistedConfigurationBundle(), [])
        }
        return decodeAndValidate(data: data)
    }

    public static func save(_ bundle: PersistedConfigurationBundle, to defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(bundle) {
            defaults.set(data, forKey: storageKey)
        }
    }

    public static func decodeAndValidate(data: Data) -> (bundle: PersistedConfigurationBundle, warnings: [String]) {
        let decoder = JSONDecoder()
        guard var decoded = try? decoder.decode(PersistedConfigurationBundle.self, from: data) else {
            return (
                PersistedConfigurationBundle(),
                ["Corrupted or incompatible configuration data detected; restored safe default configuration."]
            )
        }

        var warnings = decoded.config.validateAndSanitize()
        if decoded.schemaVersion < 2 {
            decoded.schemaVersion = 2
            warnings.append("Migrated configuration schema to version 2.")
        }

        // Ensure all core gestures have a valid entry
        for gesture in AcousticGestureType.allCases where decoded.globalMappings[gesture] == nil {
            decoded.globalMappings[gesture] = PersistedConfigurationBundle.defaultGlobalMappings[gesture] ?? .disabled
        }

        return (decoded, warnings)
    }

    public static func exportJSONData(_ bundle: PersistedConfigurationBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }
}
