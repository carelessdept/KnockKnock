import Foundation

// MARK: - Part 5 & Part 13: Pure Signal Feature Extraction, DTW Rhythm Matching & Arbitration

public enum AcousticSignalMath {
    /// Classifies an acoustic + optional motion frame using the 9-stage suppression & fusion pipeline.
    public static func classifyImpulse(
        peak: Float,
        rms: Float,
        lowBandEnergy: Float,
        midVocalEnergy: Float,
        highBandEnergy: Float,
        msSinceLastKeystroke: Double,
        config: AcousticClassifierConfig,
        corroboratingMotionJerkG: Double = 0.0,
        gyroRollDegPerSec: Double = 0.0,
        isSustainedEnvelope: Bool = false
    ) -> (kind: ImpulseKind, rejection: RejectionReason, crestFactor: Float, lowRatio: Float, highRatio: Float, zone: SpatialKnockZone)? {
        let hasMotionSpike = corroboratingMotionJerkG >= config.effectiveMotionJerkGateG
        let hasAudioSpike = peak >= config.amplitudeGate

        guard hasMotionSpike || hasAudioSpike else { return nil }

        let safeRMS = max(rms, 0.0001)
        let crestFactor = peak / safeRMS
        let totalEnergy = max(lowBandEnergy + midVocalEnergy + highBandEnergy, 0.00001)
        let lowRatio = lowBandEnergy / totalEnergy
        let vocalRatio = midVocalEnergy / totalEnergy
        let highRatio = highBandEnergy / totalEnergy
        let zone = estimateSpatialZone(
            gyroRollDegPerSec: gyroRollDegPerSec,
            leftBias: config.calibratedLeftRollBias,
            rightBias: config.calibratedRightRollBias
        )

        // Stage 1: Active keyboard / trackpad / mouse suppression
        if msSinceLastKeystroke < config.typingSuppressionWindowMs {
            return (.typingSuppressed, .typingOrMouseActive, crestFactor, lowRatio, highRatio, zone)
        }

        // Stage 2: Accelerometer-Primary Mode (ignores microphone completely)
        if config.modalityMode == .accelerometerPrimary {
            if hasMotionSpike {
                return (.motionChassisKnock, .accepted, max(crestFactor, 6.0), 0.78, 0.12, zone)
            } else {
                return (.ambientRejected, .insufficientMotionJerk, crestFactor, lowRatio, highRatio, zone)
            }
        }

        // Stage 3: Sensor Fusion Mode (BMI286 Motion + 48kHz Audio)
        if config.modalityMode == .sensorFusion {
            // 3a. Crisp upper-mid air transient WITH ZERO chassis motion -> 100% Finger Snap!
            // Because finger snaps happen in the air (corroboratingMotionJerkG < 0.010g), any sharp
            // airborne impulse that doesn't shake the MacBook chassis is classified as a Finger Snap
            // and NEVER confused with a physical chassis tap!
            if !hasMotionSpike {
                if isSustainedEnvelope || crestFactor < config.minimumCrestFactor || vocalRatio >= 0.56 {
                    return (.ambientRejected, .sustainedAudioRejected, crestFactor, lowRatio, highRatio, zone)
                }
                if highRatio >= 0.24 || crestFactor >= config.minimumCrestFactor {
                    return (.fingerSnap, .accepted, crestFactor, lowRatio, max(highRatio, 0.52), .any)
                }
                return (.ambientRejected, .insufficientMotionJerk, crestFactor, lowRatio, highRatio, zone)
            }

            // 3b. Corroborated physical knock (real instantaneous BMI286 motion spike on the chassis)
            return (.fusedChassisKnock, .accepted, max(crestFactor, 5.5), max(lowRatio, 0.65), highRatio, zone)
        }

        // Stage 4: Microphone-Only Mode
        if isSustainedEnvelope || crestFactor < config.minimumCrestFactor || vocalRatio >= 0.58 {
            return (.ambientRejected, .sustainedAudioRejected, crestFactor, lowRatio, highRatio, zone)
        }
        if lowRatio >= 0.40 && lowRatio > highRatio * 1.15 {
            return (.fusedChassisKnock, .accepted, crestFactor, lowRatio, highRatio, zone)
        }
        if highRatio >= 0.35 {
            return (.fingerSnap, .accepted, crestFactor, lowRatio, highRatio, .any)
        }
        if crestFactor >= config.minimumCrestFactor * 1.35 {
            return (lowRatio >= highRatio ? .fusedChassisKnock : .fingerSnap, .accepted, crestFactor, lowRatio, highRatio, zone)
        }

        return (.ambientRejected, .belowConfidenceThreshold, crestFactor, lowRatio, highRatio, zone)
    }

    /// Estimates the spatial impact zone on the MacBook chassis from the BMI286 gyroscope roll impulse.
    /// Tapping the left palm rest induces a negative Y-axis/roll angular velocity spike; tapping the right induces positive.
    public static func estimateSpatialZone(
        gyroRollDegPerSec: Double,
        leftBias: Double = -2.4,
        rightBias: Double = 2.4
    ) -> SpatialKnockZone {
        if gyroRollDegPerSec <= leftBias {
            return .leftPalmRest
        } else if gyroRollDegPerSec >= rightBias {
            return .rightPalmRest
        } else if abs(gyroRollDegPerSec) > 0.35 {
            return .centerOrLid
        }
        return .any
    }

    /// Evaluates whether a sequence of impulse timestamps matches a target rhythm ratio profile
    /// using normalized inter-onset intervals + Dynamic Time Warping (DTW) alignment score.
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
        let dtwPenalty = dtwNormalizedDistance(normalized, targetRatios) * 0.25
        let confidence = max(0.0, min(1.0, 1.0 - (meanError / max(tolerance, 0.05)) * 0.35 - dtwPenalty))
        return (true, confidence)
    }

    /// 1D Dynamic Time Warping (DTW) distance between two normalized interval sequences.
    public static func dtwNormalizedDistance(_ seqA: [Double], _ seqB: [Double]) -> Double {
        let n = seqA.count
        let m = seqB.count
        guard n > 0 && m > 0 else { return 1.0 }
        var dp = Array(repeating: Array(repeating: Double.infinity, count: m + 1), count: n + 1)
        dp[0][0] = 0.0
        for i in 1...n {
            for j in 1...m {
                let cost = abs(seqA[i - 1] - seqB[j - 1])
                dp[i][j] = cost + min(dp[i - 1][j], min(dp[i][j - 1], dp[i - 1][j - 1]))
            }
        }
        return dp[n][m] / Double(max(n, m))
    }
}

// MARK: - Part 13.2: Deterministic Sensor-Event Replay Engine

public struct ReplaySensorFrame: Codable, Sendable, Equatable {
    public let timestampSec: TimeInterval
    public let peakAmplitude: Float
    public let rmsAmplitude: Float
    public let lowBandEnergy: Float
    public let midVocalEnergy: Float
    public let highBandEnergy: Float
    public let motionJerkG: Double
    public let gyroRollDegPerSec: Double
    public let msSinceLastKeystroke: Double
    public let isTrackpadHeld: Bool
    public let isSimulatedSource: Bool

    public init(
        timestampSec: TimeInterval,
        peakAmplitude: Float,
        rmsAmplitude: Float,
        lowBandEnergy: Float,
        midVocalEnergy: Float,
        highBandEnergy: Float,
        motionJerkG: Double = 0.09,
        gyroRollDegPerSec: Double = 0.0,
        msSinceLastKeystroke: Double = 900,
        isTrackpadHeld: Bool = false,
        isSimulatedSource: Bool = true
    ) {
        self.timestampSec = timestampSec
        self.peakAmplitude = peakAmplitude
        self.rmsAmplitude = rmsAmplitude
        self.lowBandEnergy = lowBandEnergy
        self.midVocalEnergy = midVocalEnergy
        self.highBandEnergy = highBandEnergy
        self.motionJerkG = motionJerkG
        self.gyroRollDegPerSec = gyroRollDegPerSec
        self.msSinceLastKeystroke = msSinceLastKeystroke
        self.isTrackpadHeld = isTrackpadHeld
        self.isSimulatedSource = isSimulatedSource
    }
}

public struct ReplayEvaluationResult: Sendable, Equatable {
    public let recognizedGestures: [(gesture: AcousticGestureType, timestampSec: TimeInterval, confidence: Double)]
    public let rejectedCount: Int
    public let rejectionBreakdown: [RejectionReason: Int]

    public static func == (lhs: ReplayEvaluationResult, rhs: ReplayEvaluationResult) -> Bool {
        guard lhs.rejectedCount == rhs.rejectedCount,
              lhs.rejectionBreakdown == rhs.rejectionBreakdown,
              lhs.recognizedGestures.count == rhs.recognizedGestures.count else {
            return false
        }
        for (a, b) in zip(lhs.recognizedGestures, rhs.recognizedGestures) {
            if a.gesture != b.gesture || abs(a.timestampSec - b.timestampSec) > 0.001 || abs(a.confidence - b.confidence) > 0.001 {
                return false
            }
        }
        return true
    }
}

/// Deterministic, clock-independent state machine for replaying recorded or synthetic sensor streams
/// and verifying zero duplicate triggers, zero conflicting actions, and exact gesture arbitration.
public struct DeterministicReplayEngine: Sendable {
    public let config: AcousticClassifierConfig

    public init(config: AcousticClassifierConfig = AcousticClassifierConfig()) {
        self.config = config
    }

    public func evaluate(frames: [ReplaySensorFrame]) -> ReplayEvaluationResult {
        var knockTimes: [TimeInterval] = []
        var snapTimes: [TimeInterval] = []
        var allTimes: [TimeInterval] = []
        var lastImpulseTime: TimeInterval = -10.0
        var lastTriggerTime: TimeInterval = -10.0
        var consecutiveLoud = 0

        var pendingDoubleKnock: (time: TimeInterval, hold: Bool, zone: SpatialKnockZone)? = nil
        var recognized: [(gesture: AcousticGestureType, timestampSec: TimeInterval, confidence: Double)] = []
        var rejectedCount = 0
        var breakdown: [RejectionReason: Int] = [:]

        let disambiguationWindowSec = 0.28

        for frame in frames {
            // Check if a pending double-knock has matured past the triple-knock disambiguation window
            if let pending = pendingDoubleKnock, (frame.timestampSec - pending.time) > disambiguationWindowSec {
                let g = Self.resolveDoubleKnockGesture(hold: pending.hold, zone: pending.zone, config: config)
                recognized.append((g, pending.time + disambiguationWindowSec, 0.94))
                lastTriggerTime = pending.time + disambiguationWindowSec
                pendingDoubleKnock = nil
                knockTimes.removeAll()
                allTimes.removeAll()
            }

            let isLoud = frame.peakAmplitude >= config.amplitudeGate || frame.motionJerkG >= config.effectiveMotionJerkGateG
            if !isLoud {
                consecutiveLoud = 0
                continue
            }
            consecutiveLoud += 1
            let isSustained = consecutiveLoud > 1 && frame.motionJerkG < config.effectiveMotionJerkGateG

            guard (frame.timestampSec - lastImpulseTime) * 1000.0 >= 110.0 else { continue }

            guard let result = AcousticSignalMath.classifyImpulse(
                peak: frame.peakAmplitude,
                rms: frame.rmsAmplitude,
                lowBandEnergy: frame.lowBandEnergy,
                midVocalEnergy: frame.midVocalEnergy,
                highBandEnergy: frame.highBandEnergy,
                msSinceLastKeystroke: frame.msSinceLastKeystroke,
                config: config,
                corroboratingMotionJerkG: frame.motionJerkG,
                gyroRollDegPerSec: frame.gyroRollDegPerSec,
                isSustainedEnvelope: isSustained
            ) else {
                continue
            }

            if result.rejection != .accepted {
                rejectedCount += 1
                breakdown[result.rejection, default: 0] += 1
                if result.rejection == .sustainedAudioRejected {
                    pendingDoubleKnock = nil
                    knockTimes.removeAll()
                    snapTimes.removeAll()
                    allTimes.removeAll()
                }
                continue
            }

            lastImpulseTime = frame.timestampSec

            // Cooldown gate
            if (frame.timestampSec - lastTriggerTime) * 1000.0 < config.cooldownMs {
                rejectedCount += 1
                breakdown[.cooldownActive, default: 0] += 1
                continue
            }

            allTimes.append(frame.timestampSec)
            allTimes = allTimes.filter { (frame.timestampSec - $0) <= 3.0 }

            // 1. Check 4-beat Secret Rhythm first
            let rhythmMatch = AcousticSignalMath.matchesRhythm(
                timestamps: allTimes,
                targetRatios: config.targetRhythmRatios,
                tolerance: config.rhythmTolerance
            )
            if rhythmMatch.matched && rhythmMatch.score >= config.minimumConfidence {
                pendingDoubleKnock = nil
                allTimes.removeAll()
                knockTimes.removeAll()
                snapTimes.removeAll()
                lastTriggerTime = frame.timestampSec
                recognized.append((.secretRhythm, frame.timestampSec, rhythmMatch.score))
                continue
            }

            switch result.kind {
            case .fusedChassisKnock, .motionChassisKnock:
                knockTimes.append(frame.timestampSec)
                knockTimes = knockTimes.filter { (frame.timestampSec - $0) * 1000.0 <= config.maxDoubleIntervalMs * 2.2 }

                if knockTimes.count >= 3 {
                    let t3 = knockTimes[knockTimes.count - 1]
                    let t2 = knockTimes[knockTimes.count - 2]
                    let t1 = knockTimes[knockTimes.count - 3]
                    let d1 = (t2 - t1) * 1000.0
                    let d2 = (t3 - t2) * 1000.0
                    if d1 >= config.minDoubleIntervalMs && d1 <= config.maxDoubleIntervalMs &&
                       d2 >= config.minDoubleIntervalMs && d2 <= config.maxDoubleIntervalMs {
                        if pendingDoubleKnock != nil {
                            breakdown[.conflictArbitrated, default: 0] += 1
                        }
                        pendingDoubleKnock = nil
                        knockTimes.removeAll()
                        allTimes.removeAll()
                        lastTriggerTime = frame.timestampSec
                        recognized.append((.tripleKnock, frame.timestampSec, 0.96))
                        continue
                    }
                }

                if knockTimes.count >= 2 {
                    let t2 = knockTimes[knockTimes.count - 1]
                    let t1 = knockTimes[knockTimes.count - 2]
                    let dt = (t2 - t1) * 1000.0
                    if dt >= config.minDoubleIntervalMs && dt <= config.maxDoubleIntervalMs {
                        pendingDoubleKnock = (frame.timestampSec, frame.isTrackpadHeld, result.zone)
                    }
                }

            case .fingerSnap:
                snapTimes.append(frame.timestampSec)
                snapTimes = snapTimes.filter { (frame.timestampSec - $0) * 1000.0 <= config.maxDoubleIntervalMs * 1.5 }
                if snapTimes.count >= 2 {
                    let t2 = snapTimes[snapTimes.count - 1]
                    let t1 = snapTimes[snapTimes.count - 2]
                    let dt = (t2 - t1) * 1000.0
                    if dt >= config.minDoubleIntervalMs && dt <= config.maxDoubleIntervalMs {
                        snapTimes.removeAll()
                        allTimes.removeAll()
                        lastTriggerTime = frame.timestampSec
                        recognized.append((.doubleSnap, frame.timestampSec, 0.95))
                    }
                }

            default:
                break
            }
        }

        // Flush any remaining pending double-knock at end of stream
        if let pending = pendingDoubleKnock {
            let g = Self.resolveDoubleKnockGesture(hold: pending.hold, zone: pending.zone, config: config)
            recognized.append((g, pending.time + disambiguationWindowSec, 0.94))
        }

        return ReplayEvaluationResult(
            recognizedGestures: recognized,
            rejectedCount: rejectedCount,
            rejectionBreakdown: breakdown
        )
    }

    private static func resolveDoubleKnockGesture(
        hold: Bool,
        zone: SpatialKnockZone,
        config: AcousticClassifierConfig
    ) -> AcousticGestureType {
        if hold {
            return .trackpadHoldDoubleKnock
        }
        if config.enableExperimentalSpatialZones {
            if zone == .leftPalmRest { return .leftZoneDoubleKnock }
            if zone == .rightPalmRest { return .rightZoneDoubleKnock }
        }
        return .doubleKnock
    }
}
