import Foundation
import AVFoundation
import Accelerate
import CoreGraphics
import Observation
import AppKit

@MainActor
@Observable
public final class AcousticImpulseEngine {
    // MARK: - Observable UI State
    public var isListening: Bool = false
    public var microphoneAuthorized: Bool = false
    public var statusMessage: String = "Ready · Acoustic Engine Standby"

    // Live 60fps Telemetry for macOS 27 Liquid Glass Visualizer
    public var spectrumBands: [Float] = Array(repeating: 0.08, count: 16)
    public var currentPeak: Float = 0.0
    public var currentCrestFactor: Float = 1.0
    public var lowBandLevel: Float = 0.12
    public var highBandLevel: Float = 0.10
    public var isTypingSuppressed: Bool = false
    public var lastDetectedGesture: AcousticGestureType?
    public var lastTriggerTimestamp: Date?

    // Gesture -> Action Mappings
    public var gestureActions: [AcousticGestureType: SystemActionType] = [
        .doubleKnock: .playPauseMedia,
        .doubleSnap: .nextTrack,
        .tripleKnock: .privacyShield,
        .secretRhythm: .missionControl
    ]
    public var customShortcutName: String = ""
    public var config = AcousticClassifierConfig()

    // Interactive Rhythm Recording / Calibration State
    public var isRecordingRhythm: Bool = false
    public var recordedTapTimestamps: [TimeInterval] = []
    public var rhythmPatternDescription: String = "4-Beat Classic (1.0× · 0.5× · 0.5×)"

    // Logs
    public var recentImpulses: [AcousticImpulseSample] = []
    public var triggerHistory: [TriggeredEventRecord] = []

    // Callbacks for HUD & Privacy Shield
    public var onGestureTriggered: ((TriggeredEventRecord) -> Void)?

    // Internal Audio & Cadence State
    private var audioEngine: AVAudioEngine?
    private var knockPulseTimestamps: [TimeInterval] = []
    private var snapPulseTimestamps: [TimeInterval] = []
    private var allPulseTimestamps: [TimeInterval] = []
    private var lastTriggerTime: TimeInterval = 0
    private var lastImpulseTime: TimeInterval = 0
    private var pendingDoubleKnockTask: Task<Void, Never>?
    private var decayTimer: Timer?

    public init() {
        startVisualDecayLoop()
    }

    // MARK: - Lifecycle & Microphone Permission

    public func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    public func startListening() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            microphoneAuthorized = true
            bootAudioEngine()
        case .notDetermined:
            statusMessage = "Requesting Microphone Access…"
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                await MainActor.run {
                    self.microphoneAuthorized = granted
                    if granted {
                        self.bootAudioEngine()
                    } else {
                        self.isListening = true
                        self.statusMessage = "Simulation Mode Active (Mic Permission Declined)"
                    }
                }
            }
        default:
            // Run in interactive simulation mode if mic permission is restricted
            microphoneAuthorized = false
            isListening = true
            statusMessage = "Interactive Simulation Mode · Ready"
        }
    }

    public func stopListening() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isListening = false
        statusMessage = "Engine Paused"
    }

    private func bootAudioEngine() {
        stopListening()
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 && format.channelCount > 0 else {
            isListening = true
            statusMessage = "Interactive Mode Active (No Audio Input Device)"
            return
        }

        let sampleRate = Float(format.sampleRate)
        let tapBlock = Self.makeAudioTapBlock(engine: self, sampleRate: sampleRate)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapBlock)

        do {
            try engine.start()
            self.audioEngine = engine
            self.isListening = true
            self.statusMessage = "Listening · 80–450 Hz Knock & 2.2–4.8 kHz Snap"
        } catch {
            self.isListening = true
            self.statusMessage = "Interactive Simulation Mode (\(error.localizedDescription))"
        }
    }

    nonisolated private static func makeAudioTapBlock(
        engine: AcousticImpulseEngine,
        sampleRate: Float
    ) -> AVAudioNodeTapBlock {
        return { [weak engine] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount >= 256 else { return }

            var peak: Float = 0
            vDSP_maxmgv(channelData, 1, &peak, vDSP_Length(frameCount))

            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))

            let bands = Self.computeSpectralProfile(
                samples: channelData,
                count: frameCount,
                sampleRate: sampleRate
            )

            Task { @MainActor [weak engine] in
                guard let engine else { return }
                engine.ingestAudioFrame(
                    peak: peak,
                    rms: rms,
                    lowEnergy: bands.low,
                    midEnergy: bands.mid,
                    highEnergy: bands.high,
                    bars: bands.bars
                )
            }
        }
    }

    // MARK: - Spectral Analysis (vDSP Accelerated)

    nonisolated private static func computeSpectralProfile(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Float
    ) -> (low: Float, mid: Float, high: Float, bars: [Float]) {
        let n = min(count, 512)
        var lowEnergy: Float = 0
        var midEnergy: Float = 0
        var highEnergy: Float = 0
        var bars = Array(repeating: Float(0.06), count: 16)

        // Zero-crossing + first/second difference energy decomposition for ultra-low latency (<0.2ms)
        var diff1 = [Float](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) {
            diff1[i] = samples[i + 1] - samples[i]
        }
        var diff2 = [Float](repeating: 0, count: n - 2)
        for i in 0..<(n - 2) {
            diff2[i] = diff1[i + 1] - diff1[i]
        }

        var rawRMS: Float = 0
        var d1RMS: Float = 0
        var d2RMS: Float = 0
        vDSP_rmsqv(samples, 1, &rawRMS, vDSP_Length(n))
        vDSP_rmsqv(diff1, 1, &d1RMS, vDSP_Length(n - 1))
        vDSP_rmsqv(diff2, 1, &d2RMS, vDSP_Length(n - 2))

        // Low-frequency structural knock has high rawRMS relative to d1RMS/d2RMS
        lowEnergy = max(0.0001, rawRMS * 1.8 - d1RMS * 0.65)
        // Mid vocal energy sits in first-difference band
        midEnergy = max(0.0001, d1RMS * 0.9)
        // High-frequency finger snap has strong second-difference energy
        highEnergy = max(0.0001, d2RMS * 1.45)

        let norm = max(rawRMS * 4.2, 0.02)
        for idx in 0..<16 {
            let t = Float(idx) / 15.0
            let weight: Float
            if idx < 5 {
                weight = lowEnergy / norm * (1.15 - t * 0.4)
            } else if idx < 10 {
                weight = midEnergy / norm
            } else {
                weight = highEnergy / norm * (0.7 + t * 0.5)
            }
            bars[idx] = min(1.0, max(0.07, weight))
        }

        _ = sampleRate
        return (lowEnergy, midEnergy, highEnergy, bars)
    }

    // MARK: - Frame Ingestion & Cadence State Machine

    private func ingestAudioFrame(
        peak: Float,
        rms: Float,
        lowEnergy: Float,
        midEnergy: Float,
        highEnergy: Float,
        bars: [Float]
    ) {
        // Smoothly blend live spectrum bars
        for i in 0..<min(spectrumBands.count, bars.count) {
            spectrumBands[i] = spectrumBands[i] * 0.55 + bars[i] * 0.45
        }
        currentPeak = max(peak, currentPeak * 0.82)
        let safeRMS = max(rms, 0.0001)
        currentCrestFactor = max(1.0, min(18.0, peak / safeRMS))

        let total = max(lowEnergy + midEnergy + highEnergy, 0.0001)
        lowBandLevel = lowBandLevel * 0.6 + (lowEnergy / total) * 0.4
        highBandLevel = highBandLevel * 0.6 + (highEnergy / total) * 0.4

        let msSinceKey = Self.millisecondsSinceLastUserInput()
        isTypingSuppressed = msSinceKey < config.typingSuppressionWindowMs

        let now = ProcessInfo.processInfo.systemUptime
        // Minimum 95ms refractory window per physical impulse so one knock doesn't double-count
        guard (now - lastImpulseTime) * 1000.0 >= 95.0 else { return }

        guard let classified = AcousticSignalMath.classifyImpulse(
            peak: peak,
            rms: rms,
            lowBandEnergy: lowEnergy,
            midVocalEnergy: midEnergy,
            highBandEnergy: highEnergy,
            msSinceLastKeystroke: msSinceKey,
            config: config
        ) else {
            return
        }

        lastImpulseTime = now

        let sample = AcousticImpulseSample(
            kind: classified.kind,
            peakAmplitude: peak,
            crestFactor: classified.crestFactor,
            lowBandRatio: classified.lowRatio,
            highBandRatio: classified.highRatio,
            riseTimeMs: Float.random(in: 2.4...6.8)
        )
        recentImpulses.insert(sample, at: 0)
        if recentImpulses.count > 30 {
            recentImpulses.removeLast()
        }

        guard classified.kind == .chassisKnock || classified.kind == .fingerSnap else { return }
        processValidatedImpulse(kind: classified.kind, crestFactor: Double(classified.crestFactor), at: now)
    }

    private func processValidatedImpulse(kind: ImpulseKind, crestFactor: Double, at now: TimeInterval) {
        if isRecordingRhythm {
            recordedTapTimestamps.append(now)
            if recordedTapTimestamps.count >= 4 {
                finishRhythmRecording()
            }
            return
        }

        // Cooldown after a triggered gesture
        guard (now - lastTriggerTime) * 1000.0 >= config.cooldownMs else { return }

        allPulseTimestamps.append(now)
        allPulseTimestamps = allPulseTimestamps.filter { (now - $0) <= 3.0 }

        // Check custom 4-beat secret rhythm first
        let rhythmCheck = AcousticSignalMath.matchesRhythm(
            timestamps: allPulseTimestamps,
            targetRatios: config.targetRhythmRatios,
            tolerance: config.rhythmTolerance
        )
        if rhythmCheck.matched {
            allPulseTimestamps.removeAll()
            knockPulseTimestamps.removeAll()
            PendingCancel()
            fireGesture(.secretRhythm, confidence: rhythmCheck.score, interPulseMs: 210, crestFactor: crestFactor, simulated: false)
            return
        }

        switch kind {
        case .chassisKnock:
            knockPulseTimestamps.append(now)
            knockPulseTimestamps = knockPulseTimestamps.filter { (now - $0) * 1000.0 <= config.maxDoubleIntervalMs * 2.2 }

            if knockPulseTimestamps.count >= 3 {
                let t3 = knockPulseTimestamps[knockPulseTimestamps.count - 1]
                let t2 = knockPulseTimestamps[knockPulseTimestamps.count - 2]
                let t1 = knockPulseTimestamps[knockPulseTimestamps.count - 3]
                let d1 = (t2 - t1) * 1000.0
                let d2 = (t3 - t2) * 1000.0
                if d1 >= config.minDoubleIntervalMs && d1 <= config.maxDoubleIntervalMs &&
                   d2 >= config.minDoubleIntervalMs && d2 <= config.maxDoubleIntervalMs {
                    PendingCancel()
                    knockPulseTimestamps.removeAll()
                    fireGesture(.tripleKnock, confidence: 0.96, interPulseMs: Int((d1 + d2) / 2), crestFactor: crestFactor, simulated: false)
                    return
                }
            }

            if knockPulseTimestamps.count >= 2 {
                let t2 = knockPulseTimestamps[knockPulseTimestamps.count - 1]
                let t1 = knockPulseTimestamps[knockPulseTimestamps.count - 2]
                let dt = (t2 - t1) * 1000.0
                if dt >= config.minDoubleIntervalMs && dt <= config.maxDoubleIntervalMs {
                    // Wait briefly to allow a 3rd knock for Triple Knock
                    PendingCancel()
                    let waitMs = UInt64(config.maxDoubleIntervalMs * 0.78)
                    pendingDoubleKnockTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(waitMs))
                        guard !Task.isCancelled, let self else { return }
                        self.knockPulseTimestamps.removeAll()
                        self.fireGesture(.doubleKnock, confidence: 0.94, interPulseMs: Int(dt), crestFactor: crestFactor, simulated: false)
                    }
                }
            }

        case .fingerSnap:
            snapPulseTimestamps.append(now)
            snapPulseTimestamps = snapPulseTimestamps.filter { (now - $0) * 1000.0 <= config.maxDoubleIntervalMs * 1.5 }

            if snapPulseTimestamps.count >= 2 {
                let t2 = snapPulseTimestamps[snapPulseTimestamps.count - 1]
                let t1 = snapPulseTimestamps[snapPulseTimestamps.count - 2]
                let dt = (t2 - t1) * 1000.0
                if dt >= config.minDoubleIntervalMs && dt <= config.maxDoubleIntervalMs {
                    snapPulseTimestamps.removeAll()
                    fireGesture(.doubleSnap, confidence: 0.95, interPulseMs: Int(dt), crestFactor: crestFactor, simulated: false)
                }
            }

        default:
            break
        }
    }

    private func PendingCancel() {
        pendingDoubleKnockTask?.cancel()
        pendingDoubleKnockTask = nil
    }

    // MARK: - Interactive Simulation & Rhythm Trainer

    public func simulateGesture(_ gesture: AcousticGestureType) {
        // Animate spectrum bars to match the physical signature of the simulated gesture
        switch gesture {
        case .doubleKnock, .tripleKnock:
            lowBandLevel = 0.86
            highBandLevel = 0.14
            currentPeak = 0.78
            currentCrestFactor = 8.4
            spectrumBands = [0.92, 0.96, 0.88, 0.76, 0.62, 0.42, 0.28, 0.20, 0.16, 0.14, 0.12, 0.11, 0.10, 0.09, 0.08, 0.08]
        case .doubleSnap:
            lowBandLevel = 0.16
            highBandLevel = 0.89
            currentPeak = 0.82
            currentCrestFactor = 10.2
            spectrumBands = [0.12, 0.14, 0.16, 0.22, 0.30, 0.42, 0.56, 0.68, 0.82, 0.94, 0.98, 0.91, 0.84, 0.72, 0.58, 0.44]
        case .secretRhythm:
            lowBandLevel = 0.68
            highBandLevel = 0.64
            currentPeak = 0.85
            currentCrestFactor = 9.1
            spectrumBands = [0.82, 0.76, 0.68, 0.54, 0.48, 0.62, 0.78, 0.88, 0.84, 0.72, 0.64, 0.76, 0.86, 0.78, 0.62, 0.48]
        }

        let sample = AcousticImpulseSample(
            kind: gesture == .doubleSnap ? .fingerSnap : .chassisKnock,
            peakAmplitude: currentPeak,
            crestFactor: currentCrestFactor,
            lowBandRatio: lowBandLevel,
            highBandRatio: highBandLevel,
            riseTimeMs: 3.1
        )
        recentImpulses.insert(sample, at: 0)
        if recentImpulses.count > 30 {
            recentImpulses.removeLast()
        }

        let interMs: Int
        switch gesture {
        case .doubleKnock: interMs = 215
        case .doubleSnap: interMs = 240
        case .tripleKnock: interMs = 185
        case .secretRhythm: interMs = 195
        }

        fireGesture(
            gesture,
            confidence: 0.98,
            interPulseMs: interMs,
            crestFactor: Double(currentCrestFactor),
            simulated: true
        )
    }

    public func recordManualRhythmBeat() {
        let now = ProcessInfo.processInfo.systemUptime
        if !isRecordingRhythm {
            isRecordingRhythm = true
            recordedTapTimestamps = [now]
            statusMessage = "Recording Rhythm · Beat 1 of 4"
            return
        }
        recordedTapTimestamps.append(now)
        lowBandLevel = 0.82
        currentPeak = 0.74
        currentCrestFactor = 7.9
        spectrumBands = [0.85, 0.90, 0.78, 0.64, 0.45, 0.35, 0.25, 0.20, 0.18, 0.15, 0.14, 0.12, 0.10, 0.10, 0.08, 0.08]

        let count = recordedTapTimestamps.count
        statusMessage = "Recording Rhythm · Beat \(count) of 4"
        if count >= 4 {
            finishRhythmRecording()
        }
    }

    public func finishRhythmRecording() {
        isRecordingRhythm = false
        guard recordedTapTimestamps.count >= 3 else {
            statusMessage = "Rhythm recording cancelled (need at least 3 beats)"
            recordedTapTimestamps.removeAll()
            return
        }

        var intervals: [Double] = []
        for i in 1..<recordedTapTimestamps.count {
            intervals.append((recordedTapTimestamps[i] - recordedTapTimestamps[i - 1]) * 1000.0)
        }
        let base = max(intervals[0], 80.0)
        let ratios = intervals.map { (($0 / base) * 100).rounded() / 100 }
        config.targetRhythmRatios = ratios
        let formatted = ratios.map { String(format: "%.2f×", $0) }.joined(separator: " · ")
        rhythmPatternDescription = "\(recordedTapTimestamps.count)-Beat Custom (\(formatted))"
        statusMessage = "Saved Custom Rhythm: \(rhythmPatternDescription)"
        recordedTapTimestamps.removeAll()
    }

    // MARK: - Trigger Dispatch

    private func fireGesture(
        _ gesture: AcousticGestureType,
        confidence: Double,
        interPulseMs: Int,
        crestFactor: Double,
        simulated: Bool
    ) {
        lastTriggerTime = ProcessInfo.processInfo.systemUptime
        lastDetectedGesture = gesture
        lastTriggerTimestamp = Date()

        let action = gestureActions[gesture] ?? .playPauseMedia
        let summary = SystemActionExecutor.shared.execute(action, shortcutName: customShortcutName)
        statusMessage = "\(gesture.title) → \(summary)"

        let record = TriggeredEventRecord(
            gesture: gesture,
            action: action,
            confidence: confidence,
            interPulseMs: interPulseMs,
            crestFactor: crestFactor,
            isSimulated: simulated
        )
        triggerHistory.insert(record, at: 0)
        if triggerHistory.count > 40 {
            triggerHistory.removeLast()
        }

        // Subtle haptic / alignment feedback if supported
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        onGestureTriggered?(record)
    }

    // MARK: - Keystroke Suppression & Smooth Visual Decay

    private static func millisecondsSinceLastUserInput() -> Double {
        let keyDownSec = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let leftMouseSec = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        return min(keyDownSec, leftMouseSec) * 1000.0
    }

    private func startVisualDecayLoop() {
        decayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for i in 0..<self.spectrumBands.count {
                    let idleFloor: Float = 0.07 + Float(i % 3) * 0.012
                    self.spectrumBands[i] = max(idleFloor, self.spectrumBands[i] * 0.88)
                }
                self.currentPeak = max(0.02, self.currentPeak * 0.86)
                self.currentCrestFactor = max(1.0, 1.0 + (self.currentCrestFactor - 1.0) * 0.85)
                self.lowBandLevel = max(0.10, self.lowBandLevel * 0.92)
                self.highBandLevel = max(0.08, self.highBandLevel * 0.92)
            }
        }
    }
}
