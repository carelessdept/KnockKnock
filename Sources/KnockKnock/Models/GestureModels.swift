import Foundation
import SwiftUI

// MARK: - Part 1.2 & 1.3: Capability & Evidence Verification States

public enum CapabilityAvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case available = "Available"
    case unavailable = "Unavailable"
    case permissionRequired = "Permission Required"
    case experimental = "Experimental"
    case failed = "Failed"
}

public enum APIClassification: String, Codable, CaseIterable, Sendable {
    case publicFramework = "Public Apple Framework"
    case restrictedIOKitSPU = "User-Space IOKit SPU HID"
    case undocumented = "Undocumented (Not Used in Stable)"
}

public enum EvidenceVerificationStage: String, Codable, CaseIterable, Sendable {
    case designed = "Designed"
    case implemented = "Implemented"
    case compiled = "Compiled"
    case unitTested = "Unit-Tested"
    case integrationTested = "Integration-Tested"
    case hardwareTested = "Hardware-Tested"
    case performanceVerified = "Performance-Verified"
    case releaseReady = "Release-Ready"
}

public struct CapabilityDescriptor: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var hardwareRequirement: String
    public var apiOrAccessMethod: String
    public var classification: APIClassification
    public var requiredPermission: String
    public var detectionMethod: String
    public var status: CapabilityAvailabilityStatus
    public var verificationStage: EvidenceVerificationStage
    public var knownRisks: String
    public var testedBehavior: String
    public var fallbackStrategy: String
    public var measuredSampleRateHz: Double

    public init(
        id: String,
        name: String,
        hardwareRequirement: String,
        apiOrAccessMethod: String,
        classification: APIClassification,
        requiredPermission: String,
        detectionMethod: String,
        status: CapabilityAvailabilityStatus,
        verificationStage: EvidenceVerificationStage,
        knownRisks: String,
        testedBehavior: String,
        fallbackStrategy: String,
        measuredSampleRateHz: Double = 0
    ) {
        self.id = id
        self.name = name
        self.hardwareRequirement = hardwareRequirement
        self.apiOrAccessMethod = apiOrAccessMethod
        self.classification = classification
        self.requiredPermission = requiredPermission
        self.detectionMethod = detectionMethod
        self.status = status
        self.verificationStage = verificationStage
        self.knownRisks = knownRisks
        self.testedBehavior = testedBehavior
        self.fallbackStrategy = fallbackStrategy
        self.measuredSampleRateHz = measuredSampleRateHz
    }
}

// MARK: - Part 2 & Part 5: Sensor Modalities, Spatial Zones & Gestures

public enum SensorModalityMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case accelerometerPrimary = "accelerometer_primary"
    case sensorFusion = "sensor_fusion"
    case microphoneOnly = "microphone_only"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accelerometerPrimary:
            return "Chassis Motion Only (No Mic Required)"
        case .sensorFusion:
            return "Sensor Fusion (BMI286 Motion + 48kHz Audio)"
        case .microphoneOnly:
            return "Acoustic Only (Microphone)"
        }
    }

    public var subtitle: String {
        switch self {
        case .accelerometerPrimary:
            return "Uses 200 Hz Bosch BMI286 SPU accelerometer & gyro. Completely immune to speech, music, and room noise."
        case .sensorFusion:
            return "Combines BMI286 chassis motion for knocks with 48 kHz microphone transients for finger snaps."
        case .microphoneOnly:
            return "Fallback acoustic transient mode when SPU motion sensors are disabled."
        }
    }
}

public enum SpatialKnockZone: String, Codable, CaseIterable, Identifiable, Sendable {
    case any = "Any Chassis Zone"
    case leftPalmRest = "Left Palm Rest"
    case rightPalmRest = "Right Palm Rest"
    case centerOrLid = "Center / Display Lid"

    public var id: String { rawValue }
}

public enum AcousticGestureType: String, CaseIterable, Codable, Identifiable, Sendable {
    case doubleKnock = "double_knock"
    case tripleKnock = "triple_knock"
    case doubleSnap = "double_snap"
    case secretRhythm = "secret_rhythm"
    case trackpadHoldDoubleKnock = "trackpad_hold_double_knock"
    case leftZoneDoubleKnock = "left_zone_double_knock"
    case rightZoneDoubleKnock = "right_zone_double_knock"
    case hingeNudge = "hinge_nudge"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .doubleKnock: return "Double Knock"
        case .tripleKnock: return "Triple Knock"
        case .doubleSnap: return "Double Snap"
        case .secretRhythm: return "Custom Rhythm"
        case .trackpadHoldDoubleKnock: return "Trackpad Hold + Double Knock"
        case .leftZoneDoubleKnock: return "Left Palm-Rest Double Knock"
        case .rightZoneDoubleKnock: return "Right Palm-Rest Double Knock"
        case .hingeNudge: return "Hinge Dial Nudge (±4°)"
        }
    }

    public var subtitle: String {
        switch self {
        case .doubleKnock: return "2× Deliberate Chassis Tap · BMI286 + Audio Fusion"
        case .tripleKnock: return "3× Rapid Chassis Tap · Structural Impulse"
        case .doubleSnap: return "2× Crisp Air Impulse · 2.2–4.8 kHz Transient"
        case .secretRhythm: return "Tempo-Invariant Normalized Cadence Pattern"
        case .trackpadHoldDoubleKnock: return "Multimodal Grammar · Touch Hold + 2× Chassis Knock"
        case .leftZoneDoubleKnock: return "Experimental Spatial Zone · Negative Roll Torque"
        case .rightZoneDoubleKnock: return "Experimental Spatial Zone · Positive Roll Torque"
        case .hingeNudge: return "Experimental Lid Angle Sensor (ma981) Micro-Adjustment"
        }
    }

    public var symbolName: String {
        switch self {
        case .doubleKnock: return "hand.tap.fill"
        case .tripleKnock: return "square.stack.3d.down.right.fill"
        case .doubleSnap: return "waveform.badge.magnifyingglass"
        case .secretRhythm: return "metronome.fill"
        case .trackpadHoldDoubleKnock: return "rectangle.and.hand.point.up.left.fill"
        case .leftZoneDoubleKnock: return "lessthan.circle.fill"
        case .rightZoneDoubleKnock: return "greaterthan.circle.fill"
        case .hingeNudge: return "laptopcomputer"
        }
    }

    public var isExperimental: Bool {
        switch self {
        case .leftZoneDoubleKnock, .rightZoneDoubleKnock, .hingeNudge:
            return true
        default:
            return false
        }
    }

    public var requiresMicrophone: Bool {
        switch self {
        case .doubleSnap:
            return true
        default:
            return false
        }
    }

    public var frequencyBadge: String {
        switch self {
        case .doubleKnock: return "200HZ MOTION + FUSION"
        case .tripleKnock: return "3-PULSE CHASSIS"
        case .doubleSnap: return "AIR TRANSIENT"
        case .secretRhythm: return "DTW CADENCE"
        case .trackpadHoldDoubleKnock: return "MULTIMODAL COMBO"
        case .leftZoneDoubleKnock: return "EXP · LEFT TORQUE"
        case .rightZoneDoubleKnock: return "EXP · RIGHT TORQUE"
        case .hingeNudge: return "EXP · LID SENSOR"
        }
    }

    public static var coreGestures: [AcousticGestureType] {
        [.doubleKnock, .tripleKnock, .doubleSnap, .secretRhythm, .trackpadHoldDoubleKnock]
    }

    public static var experimentalGestures: [AcousticGestureType] {
        [.leftZoneDoubleKnock, .rightZoneDoubleKnock, .hingeNudge]
    }
}

// MARK: - Part 7: Typed System & Automation Actions

public enum SystemActionType: String, CaseIterable, Codable, Identifiable, Sendable {
    case hudPreviewOnly = "hud_preview_only"
    case playPauseMedia = "play_pause_media"
    case muteUnmuteAudio = "mute_unmute_audio"
    case nextTrack = "next_track"
    case previousTrack = "previous_track"
    case missionControl = "mission_control"
    case lockScreen = "lock_screen"
    case privacyShield = "privacy_shield"
    case launchApplication = "launch_application"
    case openURL = "open_url"
    case runShortcut = "run_shortcut"
    case runAppleScript = "run_applescript"
    case runShellWorkflow = "run_shell_workflow"
    case toggleResonWindow = "toggle_reson_window"
    case disabled = "disabled"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hudPreviewOnly: return "HUD Confirmation Only (Safe Test Mode)"
        case .playPauseMedia: return "Play / Pause Media"
        case .muteUnmuteAudio: return "Mute / Unmute System Audio"
        case .nextTrack: return "Next Media Track"
        case .previousTrack: return "Previous Media Track"
        case .missionControl: return "Mission Control"
        case .lockScreen: return "Start Screen Saver / Lock"
        case .privacyShield: return "Visual Privacy Overlay (Non-DRM)"
        case .launchApplication: return "Launch Application"
        case .openURL: return "Open Configured URL"
        case .runShortcut: return "Run macOS Shortcut"
        case .runAppleScript: return "Run Approved AppleScript"
        case .runShellWorkflow: return "Run Opt-In Shell Command"
        case .toggleResonWindow: return "Show / Hide KnockKnock X Studio"
        case .disabled: return "Disabled"
        }
    }

    public var shortTitle: String {
        switch self {
        case .hudPreviewOnly: return "HUD Only"
        case .playPauseMedia: return "Play / Pause"
        case .muteUnmuteAudio: return "Mute Audio"
        case .nextTrack: return "Next Track"
        case .previousTrack: return "Prev Track"
        case .missionControl: return "Mission Control"
        case .lockScreen: return "Lock Screen"
        case .privacyShield: return "Privacy Overlay"
        case .launchApplication: return "Launch App"
        case .openURL: return "Open URL"
        case .runShortcut: return "Shortcut"
        case .runAppleScript: return "AppleScript"
        case .runShellWorkflow: return "Shell Command"
        case .toggleResonWindow: return "Toggle UI"
        case .disabled: return "Off"
        }
    }

    public var symbolName: String {
        switch self {
        case .hudPreviewOnly: return "checkmark.bubble.fill"
        case .playPauseMedia: return "playpause.fill"
        case .muteUnmuteAudio: return "speaker.slash.fill"
        case .nextTrack: return "forward.fill"
        case .previousTrack: return "backward.fill"
        case .missionControl: return "macwindow.on.rectangle"
        case .lockScreen: return "lock.desktopcomputer"
        case .privacyShield: return "eye.slash.circle.fill"
        case .launchApplication: return "app.badge.checkmark.fill"
        case .openURL: return "safari.fill"
        case .runShortcut: return "bolt.horizontal.circle.fill"
        case .runAppleScript: return "applescript.fill"
        case .runShellWorkflow: return "terminal.fill"
        case .toggleResonWindow: return "macwindow"
        case .disabled: return "nosign"
        }
    }

    public var isDestructiveOrIntrusive: Bool {
        switch self {
        case .lockScreen, .privacyShield, .missionControl, .runShellWorkflow, .runAppleScript:
            return true
        default:
            return false
        }
    }
}

// MARK: - Part 5.5: Explicit Rejection Reasons & Telemetry Samples

public enum RejectionReason: String, Codable, CaseIterable, Sendable {
    case accepted = "Accepted"
    case typingOrMouseActive = "Suppressed: Active Keyboard/Trackpad Input"
    case sustainedAudioRejected = "Rejected: Sustained Speech/Music Envelope"
    case insufficientMotionJerk = "Rejected: No Corroborating Chassis Motion"
    case belowConfidenceThreshold = "Rejected: Below Confidence Gate"
    case cooldownActive = "Suppressed: Post-Trigger Cooldown"
    case lidMovementSuppressed = "Suppressed: Display Hinge Moving"
    case conflictArbitrated = "Superseded: Arbitrated into Higher-Order Pattern"
    case batteryPaused = "Paused: Battery Saver Policy"
}

public enum ImpulseKind: String, Codable, Sendable {
    case fusedChassisKnock = "Fused Chassis Knock (Motion + Audio)"
    case motionChassisKnock = "Motion Chassis Knock (BMI286)"
    case fingerSnap = "Air Transient / Snap (48kHz Audio)"
    case hingeNudge = "Lid Angle Micro-Nudge (ma981)"
    case typingSuppressed = "Typing / Trackpad Suppressed"
    case ambientRejected = "Ambient / Speech Rejected"
}

public struct MotionSample: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let accelX: Double // g
    public let accelY: Double // g
    public let accelZ: Double // g
    public let gyroX: Double  // deg/s
    public let gyroY: Double  // deg/s
    public let gyroZ: Double  // deg/s
    public let jerkMagnitude: Double // g high-pass delta
    public let estimatedZone: SpatialKnockZone

    public init(
        timestamp: TimeInterval,
        accelX: Double,
        accelY: Double,
        accelZ: Double,
        gyroX: Double,
        gyroY: Double,
        gyroZ: Double,
        jerkMagnitude: Double,
        estimatedZone: SpatialKnockZone
    ) {
        self.timestamp = timestamp
        self.accelX = accelX
        self.accelY = accelY
        self.accelZ = accelZ
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
        self.jerkMagnitude = jerkMagnitude
        self.estimatedZone = estimatedZone
    }
}

public struct AcousticImpulseSample: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let uptimeSeconds: TimeInterval
    public let kind: ImpulseKind
    public let rejectionReason: RejectionReason
    public let peakAmplitude: Float
    public let crestFactor: Float
    public let lowBandRatio: Float
    public let highBandRatio: Float
    public let spectralCentroidHz: Float
    public let spectralFlux: Float
    public let riseTimeMs: Float
    public let decayTimeMs: Float
    public let motionJerkG: Double
    public let gyroRollDegPerSec: Double
    public let spatialZone: SpatialKnockZone
    public let processingTimeMicros: Double

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        uptimeSeconds: TimeInterval = ProcessInfo.processInfo.systemUptime,
        kind: ImpulseKind,
        rejectionReason: RejectionReason = .accepted,
        peakAmplitude: Float,
        crestFactor: Float,
        lowBandRatio: Float,
        highBandRatio: Float,
        spectralCentroidHz: Float = 240,
        spectralFlux: Float = 0.15,
        riseTimeMs: Float = 2.8,
        decayTimeMs: Float = 14.0,
        motionJerkG: Double = 0.0,
        gyroRollDegPerSec: Double = 0.0,
        spatialZone: SpatialKnockZone = .any,
        processingTimeMicros: Double = 42.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.uptimeSeconds = uptimeSeconds
        self.kind = kind
        self.rejectionReason = rejectionReason
        self.peakAmplitude = peakAmplitude
        self.crestFactor = crestFactor
        self.lowBandRatio = lowBandRatio
        self.highBandRatio = highBandRatio
        self.spectralCentroidHz = spectralCentroidHz
        self.spectralFlux = spectralFlux
        self.riseTimeMs = riseTimeMs
        self.decayTimeMs = decayTimeMs
        self.motionJerkG = motionJerkG
        self.gyroRollDegPerSec = gyroRollDegPerSec
        self.spatialZone = spatialZone
        self.processingTimeMicros = processingTimeMicros
    }
}

public struct TriggeredEventRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let gesture: AcousticGestureType
    public let action: SystemActionType
    public let confidence: Double
    public let interPulseMs: Int
    public let crestFactor: Double
    public let motionJerkG: Double
    public let spatialZone: SpatialKnockZone
    public let recognitionLatencyMs: Double
    public let activeAppBundleID: String
    public let executionSummary: String
    public let actionSucceeded: Bool
    public let isSimulated: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        gesture: AcousticGestureType,
        action: SystemActionType,
        confidence: Double,
        interPulseMs: Int,
        crestFactor: Double,
        motionJerkG: Double = 0.08,
        spatialZone: SpatialKnockZone = .any,
        recognitionLatencyMs: Double = 24.0,
        activeAppBundleID: String = "Global",
        executionSummary: String = "Executed",
        actionSucceeded: Bool = true,
        isSimulated: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.gesture = gesture
        self.action = action
        self.confidence = confidence
        self.interPulseMs = interPulseMs
        self.crestFactor = crestFactor
        self.motionJerkG = motionJerkG
        self.spatialZone = spatialZone
        self.recognitionLatencyMs = recognitionLatencyMs
        self.activeAppBundleID = activeAppBundleID
        self.executionSummary = executionSummary
        self.actionSucceeded = actionSucceeded
        self.isSimulated = isSimulated
    }
}

// MARK: - Application Context Profiles (Part 4.3 & Part 7)

public struct AppGestureProfile: Identifiable, Codable, Sendable, Equatable {
    public var id: String // bundleIdentifier or "global"
    public var displayName: String
    public var bundleIdentifier: String
    public var isEnabled: Bool
    public var mappings: [AcousticGestureType: SystemActionType]

    public init(
        id: String,
        displayName: String,
        bundleIdentifier: String,
        isEnabled: Bool = true,
        mappings: [AcousticGestureType: SystemActionType]
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.isEnabled = isEnabled
        self.mappings = mappings
    }
}

// MARK: - Versioned Configuration Schema (Part 9 & Part 12)

public struct AcousticClassifierConfig: Codable, Sendable, Equatable {
    public var schemaVersion: Int = 2
    public var modalityMode: SensorModalityMode = .sensorFusion
    public var sensitivity: Float = 0.58          // 0.1 ... 1.0
    public var minimumConfidence: Double = 0.72   // 0.5 ... 0.98
    public var minimumCrestFactor: Float = 4.2    // Peak-to-RMS ratio for sharp transient
    public var minimumMotionJerkG: Double = 0.032 // Minimum BMI286 g-jerk for chassis knock
    public var minDoubleIntervalMs: Double = 125  // Minimum ms between knocks/snaps
    public var maxDoubleIntervalMs: Double = 480  // Maximum ms between knocks/snaps
    public var typingSuppressionWindowMs: Double = 350
    public var cooldownMs: Double = 1100
    public var pauseOnBatteryPower: Bool = false
    public var enableExperimentalSpatialZones: Bool = false
    public var enableExperimentalHingeDial: Bool = false
    public var enableShellAutomationOptIn: Bool = false

    /// Normalized relative intervals for the custom secret rhythm (default: 4-beat cadence)
    public var targetRhythmRatios: [Double] = [1.0, 0.52, 0.52]
    public var rhythmTolerance: Double = 0.22

    /// Automation parameters
    public var customShortcutName: String = ""
    public var targetApplicationPath: String = "/System/Applications/Music.app"
    public var targetURLString: String = "https://github.com/carelessdept/KnockKnock"
    public var customAppleScript: String = "display notification \"Triggered by KnockKnock X\" with title \"KnockKnock X\""
    public var customShellCommand: String = "echo 'KnockKnock X triggered'"

    /// Calibration learned baseline
    public var calibratedMeanKnockJerkG: Double = 0.085
    public var calibratedLeftRollBias: Double = -2.4
    public var calibratedRightRollBias: Double = 2.4
    public var calibrationSampleCount: Int = 0

    public init() {}

    public var amplitudeGate: Float {
        let clamped = max(0.1, min(1.0, sensitivity))
        return max(0.055, 0.23 - (clamped * 0.17))
    }

    public var effectiveMotionJerkGateG: Double {
        let clamped = Double(max(0.1, min(1.0, sensitivity)))
        return max(0.016, minimumMotionJerkG * (1.45 - clamped * 0.75))
    }

    /// Validates configuration bounds and sanitizes any out-of-range values on import.
    public mutating func validateAndSanitize() -> [String] {
        var warnings: [String] = []
        if sensitivity < 0.1 || sensitivity > 1.0 {
            sensitivity = max(0.1, min(1.0, sensitivity))
            warnings.append("Clamped sensitivity to [0.1, 1.0].")
        }
        if minimumConfidence < 0.4 || minimumConfidence > 0.99 {
            minimumConfidence = max(0.4, min(0.99, minimumConfidence))
            warnings.append("Clamped minimumConfidence to [0.4, 0.99].")
        }
        if minimumCrestFactor < 2.0 || minimumCrestFactor > 15.0 {
            minimumCrestFactor = max(2.0, min(15.0, minimumCrestFactor))
            warnings.append("Clamped minimumCrestFactor to [2.0, 15.0].")
        }
        if minimumMotionJerkG < 0.012 || minimumMotionJerkG > 0.25 {
            minimumMotionJerkG = max(0.012, min(0.25, minimumMotionJerkG))
            warnings.append("Clamped minimumMotionJerkG to [0.012, 0.25].")
        }
        if minDoubleIntervalMs < 60 || minDoubleIntervalMs > 400 {
            minDoubleIntervalMs = 125
            warnings.append("Reset invalid minDoubleIntervalMs to 125 ms.")
        }
        if maxDoubleIntervalMs <= minDoubleIntervalMs || maxDoubleIntervalMs > 1200 {
            maxDoubleIntervalMs = max(minDoubleIntervalMs + 150, 480)
            warnings.append("Adjusted maxDoubleIntervalMs to valid range.")
        }
        if targetRhythmRatios.count < 2 || targetRhythmRatios.contains(where: { $0 <= 0.05 || $0 > 5.0 }) {
            targetRhythmRatios = [1.0, 0.52, 0.52]
            warnings.append("Reset corrupted targetRhythmRatios to default 4-beat pattern.")
        }
        return warnings
    }
}
