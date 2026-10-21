import Testing
import Foundation
@testable import KnockKnock

@Suite("KnockKnock / Reson Sensor Fusion, Deterministic Replay & System Tests")
struct AcousticClassifierTests {

    // MARK: - 1. Multi-Sensor Impulse Classification & Suppression Tests (Part 13.1)

    @Test("Classifies fused BMI286 + acoustic chassis knock vs high-mid finger snap")
    func testSensorFusionImpulseClassification() {
        var config = AcousticClassifierConfig()
        config.modalityMode = .sensorFusion

        // 1. Fused Aluminum Chassis Knock: corroborated by BMI286 motion jerk (0.088g) + 80-450 Hz acoustic resonance
        let fusedKnock = AcousticSignalMath.classifyImpulse(
            peak: 0.42,
            rms: 0.055,
            lowBandEnergy: 0.66,
            midVocalEnergy: 0.20,
            highBandEnergy: 0.14,
            msSinceLastKeystroke: 500,
            config: config,
            corroboratingMotionJerkG: 0.088,
            gyroRollDegPerSec: -4.2,
            isSustainedEnvelope: false
        )
        #expect(fusedKnock != nil)
        #expect(fusedKnock?.kind == .fusedChassisKnock)
        #expect(fusedKnock?.rejection == .accepted)
        #expect(fusedKnock?.zone == .leftPalmRest)

        // 2. Crisp Finger Snap: airborne high-frequency transient (2.2-5.5 kHz) with zero chassis motion
        let snapResult = AcousticSignalMath.classifyImpulse(
            peak: 0.38,
            rms: 0.045,
            lowBandEnergy: 0.12,
            midVocalEnergy: 0.22,
            highBandEnergy: 0.66,
            msSinceLastKeystroke: 500,
            config: config,
            corroboratingMotionJerkG: 0.0,
            gyroRollDegPerSec: 0.0,
            isSustainedEnvelope: false
        )
        #expect(snapResult != nil)
        #expect(snapResult?.kind == .fingerSnap)
        #expect(snapResult?.rejection == .accepted)
    }

    @Test("Supports Accelerometer-Primary (Motion-Only) mode with Microphone completely disabled")
    func testAccelerometerPrimaryMode() {
        var config = AcousticClassifierConfig()
        config.modalityMode = .accelerometerPrimary
        config.minimumMotionJerkG = 0.032

        // Valid physical palm-rest knock with zero audio input
        let motionKnock = AcousticSignalMath.classifyImpulse(
            peak: 0.0,
            rms: 0.0,
            lowBandEnergy: 0.0,
            midVocalEnergy: 0.0,
            highBandEnergy: 0.0,
            msSinceLastKeystroke: 600,
            config: config,
            corroboratingMotionJerkG: 0.076,
            gyroRollDegPerSec: 3.8,
            isSustainedEnvelope: false
        )
        #expect(motionKnock?.kind == .motionChassisKnock)
        #expect(motionKnock?.rejection == .accepted)
        #expect(motionKnock?.zone == .rightPalmRest)

        // Loud airborne sound with sub-threshold motion is rejected in Accelerometer-Primary mode
        let loudSoundNoMotion = AcousticSignalMath.classifyImpulse(
            peak: 0.55,
            rms: 0.05,
            lowBandEnergy: 0.70,
            midVocalEnergy: 0.15,
            highBandEnergy: 0.15,
            msSinceLastKeystroke: 600,
            config: config,
            corroboratingMotionJerkG: 0.008,
            gyroRollDegPerSec: 0.2,
            isSustainedEnvelope: false
        )
        #expect(loudSoundNoMotion?.kind == .ambientRejected)
        #expect(loudSoundNoMotion?.rejection == .insufficientMotionJerk)
    }

    @Test("Enforces false-positive suppression pipeline across typing, sustained speech, and vocal formants")
    func testFalsePositiveSuppressionPipeline() {
        let config = AcousticClassifierConfig()

        // Stage 1: Active keyboard typing / trackpad click suppression
        let typingSuppressed = AcousticSignalMath.classifyImpulse(
            peak: 0.48,
            rms: 0.06,
            lowBandEnergy: 0.65,
            midVocalEnergy: 0.20,
            highBandEnergy: 0.15,
            msSinceLastKeystroke: 40, // < 165 ms window
            config: config,
            corroboratingMotionJerkG: 0.090
        )
        #expect(typingSuppressed?.kind == .typingSuppressed)
        #expect(typingSuppressed?.rejection == .typingOrMouseActive)

        // Stage 2: Sustained audio envelope (speech/music lasting multiple buffers without motion spike)
        let sustainedRejected = AcousticSignalMath.classifyImpulse(
            peak: 0.44,
            rms: 0.06,
            lowBandEnergy: 0.65,
            midVocalEnergy: 0.20,
            highBandEnergy: 0.15,
            msSinceLastKeystroke: 500,
            config: config,
            corroboratingMotionJerkG: 0.0,
            isSustainedEnvelope: true
        )
        #expect(sustainedRejected?.kind == .ambientRejected)
        #expect(sustainedRejected?.rejection == .sustainedAudioRejected)

        // Stage 3: Low crest factor continuous speech/music
        let lowCrestSpeech = AcousticSignalMath.classifyImpulse(
            peak: 0.30,
            rms: 0.18, // Crest factor = 1.66 < 4.5
            lowBandEnergy: 0.30,
            midVocalEnergy: 0.55,
            highBandEnergy: 0.15,
            msSinceLastKeystroke: 500,
            config: config
        )
        #expect(lowCrestSpeech?.kind == .ambientRejected)
        #expect(lowCrestSpeech?.rejection == .sustainedAudioRejected)

        // Stage 4: Dominant human vocal/mid-band energy (450-2200 Hz) without motion spike
        let vocalDominant = AcousticSignalMath.classifyImpulse(
            peak: 0.42,
            rms: 0.06,
            lowBandEnergy: 0.20,
            midVocalEnergy: 0.62,
            highBandEnergy: 0.18,
            msSinceLastKeystroke: 500,
            config: config
        )
        #expect(vocalDominant?.kind == .ambientRejected)
        #expect(vocalDominant?.rejection == .sustainedAudioRejected)
    }

    // MARK: - 2. Spatial Zone Estimation & Dynamic Time Warping Cadence Math (Part 13.1)

    @Test("Estimates Left Palm Rest, Right Palm Rest, and Center/Lid zones from BMI286 Gyroscope roll torque")
    func testSpatialZoneEstimation() {
        let config = AcousticClassifierConfig()

        let leftZone = AcousticSignalMath.estimateSpatialZone(
            gyroRollDegPerSec: -4.5,
            leftBias: config.calibratedLeftRollBias,
            rightBias: config.calibratedRightRollBias
        )
        #expect(leftZone == .leftPalmRest)

        let rightZone = AcousticSignalMath.estimateSpatialZone(
            gyroRollDegPerSec: 4.8,
            leftBias: config.calibratedLeftRollBias,
            rightBias: config.calibratedRightRollBias
        )
        #expect(rightZone == .rightPalmRest)

        let centerZone = AcousticSignalMath.estimateSpatialZone(
            gyroRollDegPerSec: 0.5,
            leftBias: config.calibratedLeftRollBias,
            rightBias: config.calibratedRightRollBias
        )
        #expect(centerZone == .centerOrLid)
    }

    @Test("Matches tempo-invariant 4-beat Secret Rhythm using normalized ratios + 1D Dynamic Time Warping")
    func testSecretRhythmDTWMatching() {
        let targetRatios: [Double] = [1.0, 0.50, 0.50]

        // Fast performance (400ms, 200ms, 200ms)
        let fastTimestamps: [TimeInterval] = [10.0, 10.40, 10.60, 10.80]
        let fastMatch = AcousticSignalMath.matchesRhythm(
            timestamps: fastTimestamps,
            targetRatios: targetRatios,
            tolerance: 0.18
        )
        #expect(fastMatch.matched == true)
        #expect(fastMatch.score > 0.90)

        // Slower performance (700ms, 350ms, 350ms)
        let slowTimestamps: [TimeInterval] = [20.0, 20.70, 21.05, 21.40]
        let slowMatch = AcousticSignalMath.matchesRhythm(
            timestamps: slowTimestamps,
            targetRatios: targetRatios,
            tolerance: 0.18
        )
        #expect(slowMatch.matched == true)
        #expect(slowMatch.score > 0.90)

        // Wrong rhythm (even beats 1.0, 1.0, 1.0) should not match
        let wrongTimestamps: [TimeInterval] = [30.0, 30.35, 30.70, 31.05]
        let wrongMatch = AcousticSignalMath.matchesRhythm(
            timestamps: wrongTimestamps,
            targetRatios: targetRatios,
            tolerance: 0.18
        )
        #expect(wrongMatch.matched == false)
    }

    // MARK: - 3. Deterministic Replay Engine Tests (Part 13.2)

    @Test("Deterministic Replay: Double Knock vs Triple Knock arbitration without double-firing")
    func testDeterministicReplayDoubleVsTripleKnockArbitration() {
        let engine = DeterministicReplayEngine(config: AcousticClassifierConfig())

        // Stream A: Clean Double Knock (t = 1.00s, 1.21s)
        let doubleKnockStream: [ReplaySensorFrame] = [
            ReplaySensorFrame(timestampSec: 1.00, peakAmplitude: 0.35, rmsAmplitude: 0.04, lowBandEnergy: 0.65, midVocalEnergy: 0.20, highBandEnergy: 0.15, motionJerkG: 0.082, gyroRollDegPerSec: -1.0),
            ReplaySensorFrame(timestampSec: 1.21, peakAmplitude: 0.38, rmsAmplitude: 0.04, lowBandEnergy: 0.66, midVocalEnergy: 0.20, highBandEnergy: 0.14, motionJerkG: 0.086, gyroRollDegPerSec: -1.1)
        ]
        let doubleOutcome = engine.evaluate(frames: doubleKnockStream)
        #expect(doubleOutcome.recognizedGestures.map(\.gesture) == [.doubleKnock])
        #expect(doubleOutcome.rejectionBreakdown[.conflictArbitrated, default: 0] == 0)

        // Stream B: Clean Triple Knock (t = 2.00s, 2.20s, 2.41s)
        // Must fire ONLY .tripleKnock and arbitrate/cancel the intermediate .doubleKnock!
        let tripleKnockStream: [ReplaySensorFrame] = [
            ReplaySensorFrame(timestampSec: 2.00, peakAmplitude: 0.34, rmsAmplitude: 0.04, lowBandEnergy: 0.64, midVocalEnergy: 0.21, highBandEnergy: 0.15, motionJerkG: 0.080, gyroRollDegPerSec: 1.0),
            ReplaySensorFrame(timestampSec: 2.20, peakAmplitude: 0.36, rmsAmplitude: 0.04, lowBandEnergy: 0.65, midVocalEnergy: 0.20, highBandEnergy: 0.15, motionJerkG: 0.084, gyroRollDegPerSec: 1.1),
            ReplaySensorFrame(timestampSec: 2.41, peakAmplitude: 0.39, rmsAmplitude: 0.04, lowBandEnergy: 0.67, midVocalEnergy: 0.19, highBandEnergy: 0.14, motionJerkG: 0.091, gyroRollDegPerSec: 1.2)
        ]
        let tripleOutcome = engine.evaluate(frames: tripleKnockStream)
        #expect(tripleOutcome.recognizedGestures.map(\.gesture) == [.tripleKnock])
        #expect(tripleOutcome.rejectionBreakdown[.conflictArbitrated, default: 0] == 1)
    }

    @Test("Deterministic Replay: Multimodal Trackpad-Hold + Double Knock & Spatial Left/Right Zones")
    func testDeterministicReplayMultimodalAndSpatialZones() {
        var config = AcousticClassifierConfig()
        config.enableExperimentalSpatialZones = true
        let engine = DeterministicReplayEngine(config: config)

        // 1. Trackpad-Hold + Double Knock
        let heldStream: [ReplaySensorFrame] = [
            ReplaySensorFrame(timestampSec: 5.00, peakAmplitude: 0.32, rmsAmplitude: 0.04, lowBandEnergy: 0.62, midVocalEnergy: 0.22, highBandEnergy: 0.16, motionJerkG: 0.078, gyroRollDegPerSec: -3.5, isTrackpadHeld: true),
            ReplaySensorFrame(timestampSec: 5.22, peakAmplitude: 0.36, rmsAmplitude: 0.04, lowBandEnergy: 0.65, midVocalEnergy: 0.20, highBandEnergy: 0.15, motionJerkG: 0.084, gyroRollDegPerSec: -3.8, isTrackpadHeld: true)
        ]
        let heldOutcome = engine.evaluate(frames: heldStream)
        #expect(heldOutcome.recognizedGestures.map(\.gesture) == [.trackpadHoldDoubleKnock])

        // 2. Right Palm-Rest Spatial Double Knock
        let rightZoneStream: [ReplaySensorFrame] = [
            ReplaySensorFrame(timestampSec: 8.00, peakAmplitude: 0.33, rmsAmplitude: 0.04, lowBandEnergy: 0.64, midVocalEnergy: 0.21, highBandEnergy: 0.15, motionJerkG: 0.082, gyroRollDegPerSec: 4.4),
            ReplaySensorFrame(timestampSec: 8.21, peakAmplitude: 0.36, rmsAmplitude: 0.04, lowBandEnergy: 0.66, midVocalEnergy: 0.20, highBandEnergy: 0.14, motionJerkG: 0.088, gyroRollDegPerSec: 4.9)
        ]
        let rightOutcome = engine.evaluate(frames: rightZoneStream)
        #expect(rightOutcome.recognizedGestures.map(\.gesture) == [.rightZoneDoubleKnock])
    }

    @Test("Deterministic Replay: Negative streams (Heavy Typing, Sustained Speech, Isolated Desk Bump) produce zero false triggers")
    func testDeterministicReplayNegativeStreams() {
        let engine = DeterministicReplayEngine(config: AcousticClassifierConfig())

        let negativeStream: [ReplaySensorFrame] = [
            // Rapid keyboard typing (msSinceLastKeystroke = 25ms)
            ReplaySensorFrame(timestampSec: 1.00, peakAmplitude: 0.35, rmsAmplitude: 0.04, lowBandEnergy: 0.60, midVocalEnergy: 0.25, highBandEnergy: 0.15, motionJerkG: 0.075, msSinceLastKeystroke: 25),
            ReplaySensorFrame(timestampSec: 1.18, peakAmplitude: 0.38, rmsAmplitude: 0.04, lowBandEnergy: 0.62, midVocalEnergy: 0.23, highBandEnergy: 0.15, motionJerkG: 0.080, msSinceLastKeystroke: 30),
            // Sustained loud speech / music (low crest factor, zero motion)
            ReplaySensorFrame(timestampSec: 3.00, peakAmplitude: 0.32, rmsAmplitude: 0.16, lowBandEnergy: 0.30, midVocalEnergy: 0.55, highBandEnergy: 0.15, motionJerkG: 0.002, msSinceLastKeystroke: 600),
            ReplaySensorFrame(timestampSec: 3.20, peakAmplitude: 0.35, rmsAmplitude: 0.17, lowBandEnergy: 0.30, midVocalEnergy: 0.55, highBandEnergy: 0.15, motionJerkG: 0.002, msSinceLastKeystroke: 600),
            // Single isolated desk bump at t = 6.00s (no follow-up knock)
            ReplaySensorFrame(timestampSec: 6.00, peakAmplitude: 0.40, rmsAmplitude: 0.04, lowBandEnergy: 0.68, midVocalEnergy: 0.18, highBandEnergy: 0.14, motionJerkG: 0.092, msSinceLastKeystroke: 800)
        ]

        let outcome = engine.evaluate(frames: negativeStream)
        #expect(outcome.recognizedGestures.isEmpty)
        #expect(outcome.rejectionBreakdown[.typingOrMouseActive, default: 0] == 2)
        #expect(outcome.rejectionBreakdown[.sustainedAudioRejected, default: 0] == 2)
    }

    // MARK: - 4. Persistence, Validation & Telemetry Tests (Part 8 & Part 13.1)

    @Test("Configuration validation clamps out-of-range thresholds and recovers from corrupted JSON")
    func testConfigurationValidationAndCorruptionRecovery() {
        var invalidConfig = AcousticClassifierConfig()
        invalidConfig.sensitivity = 9.99 // Out of range [0.10, 0.95]
        invalidConfig.minimumMotionJerkG = -0.5 // Out of range [0.012, 0.25]
        invalidConfig.minDoubleIntervalMs = 500
        invalidConfig.maxDoubleIntervalMs = 200 // Inverted interval bounds!
        invalidConfig.targetRhythmRatios = [] // Empty ratios!

        let warnings = invalidConfig.validateAndSanitize()
        #expect(!warnings.isEmpty)
        #expect(invalidConfig.sensitivity <= 1.0)
        #expect(invalidConfig.minimumMotionJerkG >= 0.012)
        #expect(invalidConfig.maxDoubleIntervalMs > invalidConfig.minDoubleIntervalMs)
        #expect(invalidConfig.targetRhythmRatios.count == 3)

        // Verify corrupted JSON data recovers safely with a warning without crashing
        let corruptedJSON = Data("{ \"schemaVersion\": 2, \"config\": \"corrupted\" }".utf8)
        let recovered = ConfigurationStore.decodeAndValidate(data: corruptedJSON)
        #expect(!recovered.warnings.isEmpty)
        #expect(recovered.bundle.schemaVersion == 2)
    }

    @Test("Mach kernel PerformanceMonitor and CapabilityRegistry report real host telemetry")
    @MainActor
    func testPerformanceMonitorAndCapabilityRegistry() {
        let monitor = PerformanceMonitor.shared
        monitor.sampleProcessMetrics()
        #expect(monitor.residentMemoryMB > 0.5)
        #expect(monitor.processCPUPercent >= 0.0)

        let registry = CapabilityRegistry.shared
        registry.refreshHardwareAndPermissions()
        #expect(!registry.macModelIdentifier.isEmpty)
        #expect(registry.capabilities.count >= 7)
    }
}
