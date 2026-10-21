import Foundation
import SwiftUI

// MARK: - Gesture Types & Acoustic Signatures

public enum AcousticGestureType: String, CaseIterable, Codable, Identifiable, Sendable {
    case doubleKnock = "double_knock"
    case doubleSnap = "double_snap"
    case tripleKnock = "triple_knock"
    case secretRhythm = "secret_rhythm"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .doubleKnock: return "Double Knock"
        case .doubleSnap: return "Double Snap"
        case .tripleKnock: return "Triple Knock"
        case .secretRhythm: return "Secret Rhythm"
        }
    }

    public var subtitle: String {
        switch self {
        case .doubleKnock: return "80–450 Hz · Unibody Tap"
        case .doubleSnap: return "2.2–4.8 kHz · Air Impulse"
        case .tripleKnock: return "3× Rapid Chassis Tap"
        case .secretRhythm: return "Custom Cadence Pattern"
        }
    }

    public var symbolName: String {
        switch self {
        case .doubleKnock: return "hand.tap.fill"
        case .doubleSnap: return "sparkles"
        case .tripleKnock: return "lock.shield.fill"
        case .secretRhythm: return "waveform.badge.magnifyingglass"
        }
    }

    public var accentColor: Color {
        switch self {
        case .doubleKnock: return Color(nsColor: .systemBlue)
        case .doubleSnap: return Color(nsColor: .systemCyan)
        case .tripleKnock: return Color(nsColor: .systemIndigo)
        case .secretRhythm: return Color(nsColor: .systemPurple)
        }
    }

    public var frequencyBadge: String {
        switch self {
        case .doubleKnock: return "LOW-MID STRUCTURAL"
        case .doubleSnap: return "HIGH-MID TRANSIENT"
        case .tripleKnock: return "3-PULSE BURST"
        case .secretRhythm: return "CADENCE MATCH"
        }
    }
}

// MARK: - System Actions

public enum SystemActionType: String, CaseIterable, Codable, Identifiable, Sendable {
    case hudPreviewOnly = "hud_preview_only"
    case playPauseMedia = "play_pause_media"
    case privacyShield = "privacy_shield"
    case muteUnmuteAudio = "mute_unmute_audio"
    case nextTrack = "next_track"
    case previousTrack = "previous_track"
    case missionControl = "mission_control"
    case lockScreen = "lock_screen"
    case runShortcut = "run_shortcut"
    case disabled = "disabled"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hudPreviewOnly: return "HUD Banner Only (Safe Test Mode)"
        case .playPauseMedia: return "Play / Pause Media"
        case .privacyShield: return "Liquid Glass Privacy Shield"
        case .muteUnmuteAudio: return "Mute / Unmute System Audio"
        case .nextTrack: return "Next Track"
        case .previousTrack: return "Previous Track"
        case .missionControl: return "Mission Control"
        case .lockScreen: return "Start Screen Saver / Lock"
        case .runShortcut: return "Run macOS Shortcut"
        case .disabled: return "Disabled"
        }
    }

    public var shortTitle: String {
        switch self {
        case .hudPreviewOnly: return "HUD Only"
        case .playPauseMedia: return "Play / Pause"
        case .privacyShield: return "Privacy Shield"
        case .muteUnmuteAudio: return "Mute Audio"
        case .nextTrack: return "Next Track"
        case .previousTrack: return "Prev Track"
        case .missionControl: return "Mission Control"
        case .lockScreen: return "Lock Screen"
        case .runShortcut: return "Shortcut"
        case .disabled: return "Off"
        }
    }

    public var symbolName: String {
        switch self {
        case .hudPreviewOnly: return "sparkles.rectangle.stack"
        case .playPauseMedia: return "playpause.fill"
        case .privacyShield: return "eye.slash.circle.fill"
        case .muteUnmuteAudio: return "speaker.slash.fill"
        case .nextTrack: return "forward.fill"
        case .previousTrack: return "backward.fill"
        case .missionControl: return "macwindow.on.rectangle"
        case .lockScreen: return "lock.desktopcomputer"
        case .runShortcut: return "bolt.horizontal.circle.fill"
        case .disabled: return "nosign"
        }
    }

    public var tintColor: Color {
        switch self {
        case .hudPreviewOnly: return Color(nsColor: .systemGreen)
        case .playPauseMedia: return Color(nsColor: .systemBlue)
        case .privacyShield: return Color(nsColor: .systemIndigo)
        case .muteUnmuteAudio: return Color(nsColor: .systemOrange)
        case .nextTrack, .previousTrack: return Color(nsColor: .systemCyan)
        case .missionControl: return Color(nsColor: .systemTeal)
        case .lockScreen: return Color(nsColor: .systemRed)
        case .runShortcut: return Color(nsColor: .systemPurple)
        case .disabled: return Color(nsColor: .systemGray)
        }
    }
}

// MARK: - Impulse Classification & Telemetry

public enum ImpulseKind: String, Codable, Sendable {
    case chassisKnock = "Chassis Knock"
    case fingerSnap = "Finger Snap"
    case ambientRejected = "Ambient Rejected"
    case typingSuppressed = "Typing Suppressed"
}

public struct AcousticImpulseSample: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let kind: ImpulseKind
    public let peakAmplitude: Float
    public let crestFactor: Float
    public let lowBandRatio: Float
    public let highBandRatio: Float
    public let riseTimeMs: Float

    public init(
        timestamp: Date = Date(),
        kind: ImpulseKind,
        peakAmplitude: Float,
        crestFactor: Float,
        lowBandRatio: Float,
        highBandRatio: Float,
        riseTimeMs: Float
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.peakAmplitude = peakAmplitude
        self.crestFactor = crestFactor
        self.lowBandRatio = lowBandRatio
        self.highBandRatio = highBandRatio
        self.riseTimeMs = riseTimeMs
    }
}

public struct TriggeredEventRecord: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let gesture: AcousticGestureType
    public let action: SystemActionType
    public let confidence: Double
    public let interPulseMs: Int
    public let crestFactor: Double
    public let isSimulated: Bool

    public init(
        timestamp: Date = Date(),
        gesture: AcousticGestureType,
        action: SystemActionType,
        confidence: Double,
        interPulseMs: Int,
        crestFactor: Double,
        isSimulated: Bool = false
    ) {
        self.timestamp = timestamp
        self.gesture = gesture
        self.action = action
        self.confidence = confidence
        self.interPulseMs = interPulseMs
        self.crestFactor = crestFactor
        self.isSimulated = isSimulated
    }
}

// MARK: - Pure DSP Classification & Cadence Math (Testable & Sendable)

public struct AcousticClassifierConfig: Sendable, Equatable {
    public var sensitivity: Float = 0.55          // 0.0 ... 1.0
    public var minimumCrestFactor: Float = 4.5    // Peak-to-RMS ratio for sharp transient
    public var minDoubleIntervalMs: Double = 140  // Minimum ms between knocks/snaps
    public var maxDoubleIntervalMs: Double = 460  // Maximum ms between knocks/snaps
    public var typingSuppressionWindowMs: Double = 350
    public var cooldownMs: Double = 1200

    /// Normalized relative intervals for the custom secret rhythm (default: 4-beat cadence)
    public var targetRhythmRatios: [Double] = [1.0, 0.52, 0.52]
    public var rhythmTolerance: Double = 0.18

    public init() {}

    public var amplitudeGate: Float {
        // Maps sensitivity (0.1 ... 1.0) -> gate threshold (0.22 ... 0.065) so room noise never triggers
        let clamped = max(0.1, min(1.0, sensitivity))
        return max(0.065, 0.24 - (clamped * 0.175))
    }
}

public enum AcousticSignalMath {
    /// Classifies a single acoustic frame given band energies, peak, RMS, and typing state.
    public static func classifyImpulse(
        peak: Float,
        rms: Float,
        lowBandEnergy: Float,
        midVocalEnergy: Float,
        highBandEnergy: Float,
        msSinceLastKeystroke: Double,
        config: AcousticClassifierConfig
    ) -> (kind: ImpulseKind, crestFactor: Float, lowRatio: Float, highRatio: Float)? {
        guard peak >= config.amplitudeGate else { return nil }

        let safeRMS = max(rms, 0.0001)
        let crestFactor = peak / safeRMS

        if msSinceLastKeystroke < config.typingSuppressionWindowMs {
            return (.typingSuppressed, crestFactor, 0, 0)
        }

        let totalEnergy = max(lowBandEnergy + midVocalEnergy + highBandEnergy, 0.00001)
        let lowRatio = lowBandEnergy / totalEnergy
        let vocalRatio = midVocalEnergy / totalEnergy
        let highRatio = highBandEnergy / totalEnergy

        // Reject sustained vocal/music frames where crest factor is low or vocal band dominates
        guard crestFactor >= config.minimumCrestFactor && vocalRatio < 0.68 else {
            return (.ambientRejected, crestFactor, lowRatio, highRatio)
        }

        // Finger Snap / Clap: crisp upper-mid click (2.2–4.8 kHz dominates strongly)
        if highRatio >= 0.34 && highRatio > lowRatio * 1.15 {
            return (.fingerSnap, crestFactor, lowRatio, highRatio)
        }

        // Chassis Knock: structural low-mid thump on MacBook unibody or desk
        if lowRatio >= 0.24 {
            return (.chassisKnock, crestFactor, lowRatio, highRatio)
        }

        return (lowRatio >= highRatio ? .chassisKnock : .fingerSnap, crestFactor, lowRatio, highRatio)
    }

    /// Evaluates whether a sequence of impulse timestamps (in seconds) matches a target rhythm ratio profile.
    public static func matchesRhythm(
        timestamps: [TimeInterval],
        targetRatios: [Double],
        tolerance: Double
    ) -> (matched: Bool, score: Double) {
        let neededIntervals = targetRatios.count
        guard neededIntervals >= 2, timestamps.count >= neededIntervals + 1 else {
            return (false, 0)
        }

        let recent = Array(timestamps.suffix(neededIntervals + 1))
        var intervals: [Double] = []
        for i in 1..<recent.count {
            let dt = (recent[i] - recent[i - 1]) * 1000.0
            // Reject if any beat gap is impossibly fast (<80ms) or too slow (>950ms)
            if dt < 80.0 || dt > 950.0 {
                return (false, 0)
            }
            intervals.append(dt)
        }

        let baseInterval = max(intervals[0], 1.0)
        let normalized = intervals.map { $0 / baseInterval }

        var totalError = 0.0
        for (actual, expected) in zip(normalized, targetRatios) {
            let err = abs(actual - expected) / max(expected, 0.25)
            if err > tolerance {
                return (false, max(0, 1.0 - err))
            }
            totalError += err
        }

        let meanError = totalError / Double(neededIntervals)
        let confidence = max(0.0, min(1.0, 1.0 - (meanError / tolerance) * 0.35))
        return (true, confidence)
    }
}
