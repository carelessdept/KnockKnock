import Testing
import Foundation
@testable import KnockKnock

@Suite("KnockKnock Acoustic DSP & Cadence Classifier Tests")
struct AcousticClassifierTests {

    @Test("Classifies low-mid dominant unibody knock vs high-mid finger snap")
    func testImpulseClassification() {
        let config = AcousticClassifierConfig()

        // 1. Aluminum chassis knock: high crest factor + dominant 80-450 Hz energy
        let knockResult = AcousticSignalMath.classifyImpulse(
            peak: 0.42,
            rms: 0.06,
            lowBandEnergy: 0.65,
            midVocalEnergy: 0.20,
            highBandEnergy: 0.15,
            msSinceLastKeystroke: 500,
            config: config
        )
        #expect(knockResult?.kind == .chassisKnock)

        // 2. Crisp finger snap: high crest factor + dominant 2.2-4.8 kHz energy
        let snapResult = AcousticSignalMath.classifyImpulse(
            peak: 0.38,
            rms: 0.05,
            lowBandEnergy: 0.14,
            midVocalEnergy: 0.22,
            highBandEnergy: 0.64,
            msSinceLastKeystroke: 500,
            config: config
        )
        #expect(snapResult?.kind == .fingerSnap)

        // 3. Keystroke immunity guard suppresses impulses during active typing
        let typingSuppressed = AcousticSignalMath.classifyImpulse(
            peak: 0.48,
            rms: 0.06,
            lowBandEnergy: 0.65,
            midVocalEnergy: 0.20,
            highBandEnergy: 0.15,
            msSinceLastKeystroke: 40,
            config: config
        )
        #expect(typingSuppressed?.kind == .typingSuppressed)

        // 4. Low crest factor continuous speech/music is rejected
        let continuousSpeech = AcousticSignalMath.classifyImpulse(
            peak: 0.30,
            rms: 0.18, // Crest factor = 1.66 < 4.2
            lowBandEnergy: 0.30,
            midVocalEnergy: 0.55,
            highBandEnergy: 0.15,
            msSinceLastKeystroke: 500,
            config: config
        )
        #expect(continuousSpeech?.kind == .ambientRejected)
    }

    @Test("Matches tempo-invariant 4-beat Secret Rhythm across fast and slow tempos")
    func testSecretRhythmCadenceMatching() {
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

    @Test("Sensitivity slider inversely scales amplitude gate")
    func testSensitivityGateMapping() {
        var lowSens = AcousticClassifierConfig()
        lowSens.sensitivity = 0.25

        var highSens = AcousticClassifierConfig()
        highSens.sensitivity = 0.90

        #expect(highSens.amplitudeGate < lowSens.amplitudeGate)
    }
}
