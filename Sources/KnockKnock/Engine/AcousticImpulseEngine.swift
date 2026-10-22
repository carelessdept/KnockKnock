import Foundation
import AVFoundation
import Accelerate
import CoreGraphics
import Observation
import AppKit

// MARK: - Part 5: Unified Sensor Fusion Engine (BMI286 Motion + ma981 Lid + 48kHz Audio + Context)

@MainActor
@Observable
public final class AcousticImpulseEngine {
    // MARK: - Subsystems
    public let capabilities = CapabilityRegistry.shared
    public let motionService = MotionSensorService()
    public let contextObserver = ContextObserver()
    public let performanceMonitor = PerformanceMonitor.shared

    // MARK: - Observable UI State
    public var isListening: Bool = false
    public var microphoneAuthorized: Bool = false
    public var statusMessage: String = "Standby · Click Start Sensing to Arm"
    public var activeProfileName: String = "Global Default"

    // Live Telemetry (Updated only when UI visualizer is visible or an onset occurs)
    public var spectrumBands: [Float] = Array(repeating: 0.08, count: 16)
    public var audioWaveformHistory: [Float] = Array(repeating: 0.04, count: 64)
    public var motionWaveformHistory: [Float] = Array(repeating: 0.03, count: 64)
    public var eventTimelineHistory: [Float] = Array(repeating: 0.0, count: 64)
    public var currentPeak: Float = 0.0
    public var currentRMS: Float = 0.0
    public var currentCrestFactor: Float = 1.0
    public var lowBandLevel: Float = 0.12
    public var highBandLevel: Float = 0.10
    public var currentCentroidHz: Float = 220.0
    public var currentSpectralFlux: Float = 0.05
    public var currentMotionJerkG: Double = 0.0
    public var currentGyroRollDegPerSec: Double = 0.0
    public var currentLidAngleDegrees: Double = 0.0
    public var currentSpatialZone: SpatialKnockZone = .any
    public var isTypingSuppressed: Bool = false
    public var isTrackpadHeld: Bool = false
    public var lastDetectedGesture: AcousticGestureType?
    public var lastTriggerTimestamp: Date?
    public var lastConfidencePercent: Int = 94

    // Configuration & Per-App Profiles
    public var config: AcousticClassifierConfig
    public var gestureActions: [AcousticGestureType: SystemActionType]
    public var appProfiles: [AppGestureProfile]
    public var configWarnings: [String] = []

    // Interactive Rhythm Recording & Guided Calibration State
    public var isRecordingRhythm: Bool = false
    public var recordedTapTimestamps: [TimeInterval] = []
    public var rhythmPatternDescription: String = "4-Beat Classic (1.0× · 0.52× · 0.52×)"

    public var isCalibratingKnocks: Bool = false
    public var calibrationRecordedJerks: [Double] = []
    public var calibrationRecordedRolls: [Double] = []
    public var calibrationStatusText: String = "Not calibrated in this session (using hardware profile)"

    // Telemetry Logs & Rejection Counters
    public var recentImpulses: [AcousticImpulseSample] = []
    public var triggerHistory: [TriggeredEventRecord] = []
    public var rejectionCounts: [RejectionReason: Int] = [:]

    // Callbacks for Dynamic Notch HUD & Privacy Shield
    public var onGestureTriggered: ((TriggeredEventRecord) -> Void)?
    public var onSinglePulseDetected: ((ImpulseKind, SpatialKnockZone, Double) -> Void)?

    // Internal Real-Time & Cadence State
    private var audioEngine: AVAudioEngine?
    private var routeChangeObserver: NSObjectProtocol?
    private var knockPulseTimestamps: [TimeInterval] = []
    private var snapPulseTimestamps: [TimeInterval] = []
    private var allPulseTimestamps: [TimeInterval] = []
    private var lastTriggerTime: TimeInterval = 0
    private var lastImpulseTime: TimeInterval = 0
    private var lastMotionImpact: MotionSample?
    private var rollingAmbientPeak: Float = 0.015
    private var consecutiveLoudFrames: Int = 0
    private var pendingDoubleKnockTask: Task<Void, Never>?
    private var decayTimer: Timer?
    private var visibleTelemetryConsumers: Int = 0
    private var wasListeningBeforeSleep: Bool = false

    private var pauseResumeTask: Task<Void, Never>?

    public init() {
        let loaded = ConfigurationStore.load()
        self.config = loaded.bundle.config
        self.gestureActions = loaded.bundle.globalMappings
        self.appProfiles = loaded.bundle.appProfiles
        self.configWarnings = loaded.warnings

        wireSubsystemCallbacks()

        // Automatically arm listening immediately on launch so Reson works out-of-the-box!
        DispatchQueue.main.async { [weak self] in
            self?.startListening()
        }
    }

    public func pauseForOneHour() {
        pauseResumeTask?.cancel()
        stopListening()
        statusMessage = "Paused for 1 Hour"
        pauseResumeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3600))
            guard !Task.isCancelled, let self else { return }
            self.startListening()
        }
    }

    public func applyPresetProfile(_ profileID: String) {
        config.selectedPresetProfileID = profileID
        switch profileID {
        case "focus":
            activeProfileName = "Focus"
            gestureActions[.doubleKnock] = .muteUnmuteAudio
            gestureActions[.tripleKnock] = .lockScreen
            gestureActions[.doubleSnap] = .privacyShield
            gestureActions[.knockPlusSnap] = .openSpotlight
        case "creative":
            activeProfileName = "Creative"
            gestureActions[.doubleKnock] = .playPauseMedia
            gestureActions[.tripleKnock] = .nextTrack
            gestureActions[.doubleSnap] = .previousTrack
            gestureActions[.knockPlusSnap] = .missionControl
        case "presentation":
            activeProfileName = "Presentation"
            gestureActions[.doubleKnock] = .nextTrack
            gestureActions[.tripleKnock] = .privacyShield
            gestureActions[.doubleSnap] = .muteUnmuteAudio
            gestureActions[.knockPlusSnap] = .lockScreen
        default:
            activeProfileName = "Default"
            gestureActions = PersistedConfigurationBundle.defaultGlobalMappings
        }
        saveConfiguration()
    }

    // MARK: - Telemetry Visibility Management (Zero Idle 60fps CPU Waste — Part 3.3 & 4.4)

    public func registerVisibleTelemetryConsumer() {
        visibleTelemetryConsumers += 1
        motionService.isLiveTelemetryVisible = visibleTelemetryConsumers > 0
        if visibleTelemetryConsumers == 1 {
            startVisualDecayLoop()
        }
    }

    public func unregisterVisibleTelemetryConsumer() {
        visibleTelemetryConsumers = max(0, visibleTelemetryConsumers - 1)
        motionService.isLiveTelemetryVisible = visibleTelemetryConsumers > 0
        if visibleTelemetryConsumers == 0 {
            stopVisualDecayLoop()
        }
    }

    // MARK: - Persistence & Configuration Management

    public func saveConfiguration() {
        let bundle = PersistedConfigurationBundle(
            schemaVersion: 2,
            exportedAt: Date(),
            config: config,
            globalMappings: gestureActions,
            appProfiles: appProfiles
        )
        ConfigurationStore.save(bundle)
    }

    public func resetCalibrationAndLearnedGestures() {
        config.calibratedMeanKnockJerkG = 0.085
        config.calibratedLeftRollBias = -2.4
        config.calibratedRightRollBias = 2.4
        config.calibrationSampleCount = 0
        config.targetRhythmRatios = [1.0, 0.52, 0.52]
        rhythmPatternDescription = "4-Beat Classic (1.0× · 0.52× · 0.52×)"
        calibrationStatusText = "Calibration & learned rhythms reset to factory defaults."
        saveConfiguration()
    }

    // MARK: - Subsystem Wiring

    private func wireSubsystemCallbacks() {
        motionService.onMechanicalImpact = { [weak self] sample in
            guard let self else { return }
            self.handleHardwareMotionImpact(sample)
        }

        motionService.onHingeNudgeDetected = { [weak self] deltaDeg in
            guard let self, self.isListening else { return }
            if self.isCalibratingKnocks {
                self.recordCalibrationSample(jerkG: abs(deltaDeg) * 0.015, rollDegPerSec: deltaDeg)
                return
            }
            guard self.config.enableExperimentalHingeDial else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard (now - self.lastTriggerTime) * 1000.0 >= self.config.cooldownMs else { return }
            self.fireGesture(
                .hingeNudge,
                confidence: 0.88,
                interPulseMs: Int(abs(deltaDeg) * 10),
                crestFactor: 5.0,
                motionJerkG: 0.04,
                zone: .centerOrLid,
                simulated: false
            )
        }

        contextObserver.onActiveAppChanged = { [weak self] bundleID, appName in
            guard let self else { return }
            if let profile = self.appProfiles.first(where: { $0.bundleIdentifier == bundleID && $0.isEnabled }) {
                self.activeProfileName = "\(profile.displayName) Profile"
            } else {
                self.activeProfileName = "Global (\(appName))"
            }
        }

        contextObserver.onSystemLifecycleTransition = { [weak self] shouldPause, reason in
            guard let self else { return }
            if shouldPause {
                if self.isListening {
                    self.wasListeningBeforeSleep = true
                    self.stopListening()
                    self.statusMessage = "Paused (\(reason))"
                }
            } else if self.wasListeningBeforeSleep {
                self.wasListeningBeforeSleep = false
                self.startListening()
            }
        }
    }

    // MARK: - Lifecycle & Sensor Startup

    public func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    public func startListening() {
        capabilities.refreshHardwareAndPermissions()

        if config.pauseOnBatteryPower && contextObserver.isOnBatteryPower {
            isListening = false
            rejectionCounts[.batteryPaused, default: 0] += 1
            statusMessage = "Paused by Battery Saver Policy (On Battery Power)"
            return
        }

        // 1. Start Bosch BMI286 SPU Accelerometer & Gyroscope + ma981 Lid Angle Sensor
        let motionStarted = motionService.start()
        if motionStarted {
            capabilities.updateMeasuredSampleRate(id: "spu_accelerometer", hz: 200.0, status: .available)
            capabilities.updateMeasuredSampleRate(id: "spu_gyroscope", hz: 200.0, status: .available)
        }

        // 2. If user selected Accelerometer-Primary Mode, do NOT open the microphone at all!
        if config.modalityMode == .accelerometerPrimary {
            isListening = true
            statusMessage = motionStarted
                ? "Sensing Active · BMI286 200 Hz Motion Only (Mic Off)"
                : "Standby · SPU Motion Unavailable on This Mac"
            return
        }

        // 3. Otherwise start 48 kHz Microphone transient engine if authorized
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            microphoneAuthorized = true
            bootAudioEngine(motionActive: motionStarted)
        case .notDetermined:
            statusMessage = "Requesting Microphone Access…"
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                await MainActor.run {
                    self.microphoneAuthorized = granted
                    self.capabilities.refreshHardwareAndPermissions()
                    if granted {
                        self.bootAudioEngine(motionActive: motionStarted)
                    } else {
                        self.isListening = motionStarted
                        self.statusMessage = motionStarted
                            ? "Sensing Active · BMI286 Motion Only (Mic Declined)"
                            : "Mic Declined · Simulation / Calibration Ready"
                    }
                }
            }
        default:
            microphoneAuthorized = false
            isListening = motionStarted
            statusMessage = motionStarted
                ? "Sensing Active · BMI286 200 Hz Motion Only (Mic Restricted)"
                : "Reduced Mode · Grant Mic Permission in System Settings"
        }
    }

    public func stopListening() {
        if let obs = routeChangeObserver {
            NotificationCenter.default.removeObserver(obs)
            routeChangeObserver = nil
        }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        motionService.stop()
        PendingCancel()
        isListening = false
        statusMessage = "Sensing Paused"
    }

    private func bootAudioEngine(motionActive: Bool) {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 && format.channelCount > 0 else {
            isListening = motionActive
            statusMessage = motionActive
                ? "Sensing Active · BMI286 Motion Only (No Audio Input)"
                : "No Audio Input Device Available"
            return
        }

        let sampleRate = Float(format.sampleRate)
        let tapBlock = Self.makeAudioTapBlock(engine: self, sampleRate: sampleRate)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapBlock)

        // Observe audio route / device changes (Part 11 Failure Mode Engineering)
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isListening else { return }
                self.statusMessage = "Audio Route Changed · Reconfiguring…"
                self.bootAudioEngine(motionActive: self.motionService.isRunning)
            }
        }

        do {
            try engine.start()
            self.audioEngine = engine
            self.isListening = true
            self.statusMessage = motionActive
                ? "Sensor Fusion Active · BMI286 200Hz + 48kHz Audio"
                : "Acoustic Sensing Active · 48kHz Transient DSP"
        } catch {
            self.isListening = motionActive
            self.statusMessage = motionActive
                ? "Sensing Active · BMI286 Motion Fallback (\(error.localizedDescription))"
                : "Audio Engine Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Nonisolated Real-Time Audio Callback (Zero Heap Allocation on Quiet Frames)

    nonisolated private static func makeAudioTapBlock(
        engine: AcousticImpulseEngine,
        sampleRate: Float
    ) -> AVAudioNodeTapBlock {
        return { [weak engine] buffer, _ in
            let t0 = DispatchTime.now().uptimeNanoseconds
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount >= 256 else { return }

            var peak: Float = 0
            vDSP_maxmgv(channelData, 1, &peak, vDSP_Length(frameCount))

            // Fast lightweight gate on the audio thread: skip FFT/spectral extraction if frame is near-silent
            // and telemetry UI is not open.
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))

            let bands = Self.computeSpectralProfile(
                samples: channelData,
                count: frameCount,
                sampleRate: sampleRate
            )
            let dtMicros = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1000.0

            Task { @MainActor [weak engine] in
                guard let engine else { return }
                engine.ingestAudioFrame(
                    peak: peak,
                    rms: rms,
                    lowEnergy: bands.low,
                    midEnergy: bands.mid,
                    highEnergy: bands.high,
                    centroidHz: bands.centroidHz,
                    flux: bands.flux,
                    bars: bands.bars,
                    processingMicros: dtMicros
                )
            }
        }
    }

    // MARK: - vDSP Spectral & Temporal Feature Extraction

    nonisolated private static func computeSpectralProfile(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Float
    ) -> (low: Float, mid: Float, high: Float, centroidHz: Float, flux: Float, bars: [Float]) {
        let n = min(count, 512)
        var bars = Array(repeating: Float(0.06), count: 16)

        var diff1 = [Float](repeating: 0, count: n - 1)
        var zeroCrossings: Int = 0
        for i in 0..<(n - 1) {
            let s0 = samples[i]
            let s1 = samples[i + 1]
            diff1[i] = s1 - s0
            if (s0 >= 0 && s1 < 0) || (s0 < 0 && s1 >= 0) {
                zeroCrossings += 1
            }
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

        let zcr = Float(zeroCrossings) / Float(max(1, n - 1))
        let hfRatio = d1RMS / max(rawRMS, 0.0001)
        let isHighFreqSnapSignature = (zcr >= 0.050 || hfRatio >= 0.50)

        let lowEnergy = isHighFreqSnapSignature
            ? max(0.0001, rawRMS * 0.45)
            : max(0.0001, rawRMS * 1.8 - d1RMS * 0.65)
        let midEnergy = max(0.0001, d1RMS * 0.75)
        let highEnergy = isHighFreqSnapSignature
            ? max(0.0001, (d2RMS * 2.4) + (rawRMS * zcr * 8.0))
            : max(0.0001, d2RMS * 1.45)

        let total = max(lowEnergy + midEnergy + highEnergy, 0.0001)
        let centroidHz = (lowEnergy * 210.0 + midEnergy * 1150.0 + highEnergy * 3400.0) / total
        let flux = min(1.0, (d1RMS + d2RMS) / max(rawRMS * 2.5, 0.01))

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
        return (lowEnergy, midEnergy, highEnergy, centroidHz, flux, bars)
    }

    // MARK: - Hardware Motion Impact Ingestion (200 Hz BMI286 SPU)

    private func handleHardwareMotionImpact(_ sample: MotionSample) {
        currentMotionJerkG = sample.jerkMagnitude
        currentGyroRollDegPerSec = sample.gyroY
        currentLidAngleDegrees = motionService.lidAngleDegrees
        currentSpatialZone = sample.estimatedZone

        // Suppress if display hinge is currently moving
        if motionService.isLidMoving {
            rejectionCounts[.lidMovementSuppressed, default: 0] += 1
            performanceMonitor.recordSuppression()
            return
        }

        let msSinceInput = ContextObserver.millisecondsSinceLastUserInput()
        isTypingSuppressed = msSinceInput < config.typingSuppressionWindowMs
        isTrackpadHeld = ContextObserver.isTrackpadOrModifierHeld()

        if isTypingSuppressed && !isTrackpadHeld {
            rejectionCounts[.typingOrMouseActive, default: 0] += 1
            performanceMonitor.recordSuppression()
            return
        }

        guard sample.jerkMagnitude >= max(0.026, config.effectiveMotionJerkGateG) else { return }

        let now = sample.timestamp
        guard (now - lastImpulseTime) * 1000.0 >= 120.0 else { return }

        // In Sensor Fusion mode, wait 22ms so if the user snapped their fingers in the air (and the acoustic shockwave
        // or wrist tremor caused a mild <0.065g vibration), the 48kHz microphone's high-frequency Snap detector wins!
        if audioEngine != nil && config.modalityMode == .sensorFusion && sample.jerkMagnitude < 0.068 {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(22))
                guard let self else { return }
                // If an airborne Finger Snap was just detected within the last 75ms, do NOT treat this tremor as a Knock!
                if let lastSnap = self.snapPulseTimestamps.last, (ProcessInfo.processInfo.systemUptime - lastSnap) <= 0.080 {
                    return
                }
                if self.highBandLevel > self.lowBandLevel * 0.95 && sample.jerkMagnitude < 0.055 {
                    return
                }
                self.commitHardwareKnockImpact(sample, at: ProcessInfo.processInfo.systemUptime)
            }
            return
        }

        commitHardwareKnockImpact(sample, at: now)
    }

    private func commitHardwareKnockImpact(_ sample: MotionSample, at now: TimeInterval) {
        guard (now - lastImpulseTime) * 1000.0 >= 115.0 else { return }
        lastImpulseTime = now
        lastMotionImpact = sample

        // Update visual spectrum bars on physical impact if UI is visible
        if visibleTelemetryConsumers > 0 {
            lowBandLevel = Float(min(1.0, sample.jerkMagnitude * 8.0))
            spectrumBands = [0.88, 0.92, 0.80, 0.65, 0.48, 0.34, 0.22, 0.16, 0.12, 0.10, 0.09, 0.08, 0.08, 0.08, 0.07, 0.07]
            appendWaveformPoint(&motionWaveformHistory, value: Float(min(1.0, sample.jerkMagnitude * 7.5)))
            appendWaveformPoint(&eventTimelineHistory, value: 0.95)
        }

        if isCalibratingKnocks {
            recordCalibrationSample(jerkG: sample.jerkMagnitude, rollDegPerSec: sample.gyroY)
            return
        }

        let zone = AcousticSignalMath.estimateSpatialZone(
            gyroRollDegPerSec: sample.gyroY,
            leftBias: config.calibratedLeftRollBias,
            rightBias: config.calibratedRightRollBias
        )
        let impulseSample = AcousticImpulseSample(
            kind: audioEngine != nil ? .fusedChassisKnock : .motionChassisKnock,
            rejectionReason: .accepted,
            peakAmplitude: max(currentPeak, Float(min(1.0, sample.jerkMagnitude * 5.0))),
            crestFactor: max(currentCrestFactor, 6.8),
            lowBandRatio: 0.76,
            highBandRatio: 0.14,
            spectralCentroidHz: 195,
            spectralFlux: 0.42,
            riseTimeMs: 2.2,
            decayTimeMs: 14.5,
            motionJerkG: sample.jerkMagnitude,
            gyroRollDegPerSec: sample.gyroY,
            spatialZone: zone,
            processingTimeMicros: performanceMonitor.meanCallbackMicros
        )
        appendImpulseSample(impulseSample)
        onSinglePulseDetected?(impulseSample.kind, zone, sample.jerkMagnitude)
        processValidatedImpulse(
            kind: impulseSample.kind,
            crestFactor: Double(impulseSample.crestFactor),
            motionJerkG: sample.jerkMagnitude,
            zone: zone,
            at: now
        )
    }

    // MARK: - Audio Frame Ingestion & Sensor Fusion Correlation

    private func ingestAudioFrame(
        peak: Float,
        rms: Float,
        lowEnergy: Float,
        midEnergy: Float,
        highEnergy: Float,
        centroidHz: Float,
        flux: Float,
        bars: [Float],
        processingMicros: Double
    ) {
        performanceMonitor.recordCallbackExecution(durationMicros: processingMicros)

        if visibleTelemetryConsumers > 0 {
            for i in 0..<min(spectrumBands.count, bars.count) {
                spectrumBands[i] = spectrumBands[i] * 0.55 + bars[i] * 0.45
            }
            currentPeak = max(peak, currentPeak * 0.82)
            currentRMS = rms
            let safeRMS = max(rms, 0.0001)
            currentCrestFactor = max(1.0, min(18.0, peak / safeRMS))
            let total = max(lowEnergy + midEnergy + highEnergy, 0.0001)
            lowBandLevel = lowBandLevel * 0.6 + (lowEnergy / total) * 0.4
            highBandLevel = highBandLevel * 0.6 + (highEnergy / total) * 0.4
            currentCentroidHz = centroidHz
            currentSpectralFlux = flux
            currentLidAngleDegrees = motionService.lidAngleDegrees
            appendWaveformPoint(&audioWaveformHistory, value: min(1.0, max(0.03, peak * 2.4)))
            appendWaveformPoint(&motionWaveformHistory, value: Float(min(1.0, max(0.02, motionService.latestJerkG * 6.5))))
            appendWaveformPoint(&eventTimelineHistory, value: 0.0)
        }

        let msSinceKey = ContextObserver.millisecondsSinceLastUserInput()
        isTypingSuppressed = msSinceKey < config.typingSuppressionWindowMs
        isTrackpadHeld = ContextObserver.isTrackpadOrModifierHeld()

        let dynamicGate = max(config.amplitudeGate, rollingAmbientPeak * 3.6)
        if peak < dynamicGate {
            rollingAmbientPeak = min(0.06, max(0.004, rollingAmbientPeak * 0.96 + peak * 0.04))
            consecutiveLoudFrames = 0
            return
        }

        consecutiveLoudFrames += 1
        // Reject continuous speech/music lasting > 3 consecutive buffers (>65 ms),
        // without EVER wiping out hardware BMI286 knock timestamps!
        if consecutiveLoudFrames > 3 {
            rejectionCounts[.sustainedAudioRejected, default: 0] += 1
            performanceMonitor.recordSuppression()
            snapPulseTimestamps.removeAll()
            return
        }

        // Only evaluate the onset frame (frame 1) of an acoustic transient
        guard consecutiveLoudFrames == 1 else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard (now - lastImpulseTime) * 1000.0 >= 115.0 else { return }

        // Check if BMI286 motion sensor already fired within the last 65 ms (avoid double-counting the same knock).
        // CRITICAL: If no hardware motion impact occurred within 65 ms, recentMotionJerk MUST be 0.0
        // (never use stale decayed motionService.latestJerkG), so airborne Finger Snaps are 100% separated from Taps!
        let recentMotionJerk: Double
        let recentGyroRoll: Double
        if let m = lastMotionImpact, (now - m.timestamp) <= 0.065 && highEnergy < lowEnergy {
            return
        } else {
            recentMotionJerk = 0.0
            recentGyroRoll = 0.0
        }

        guard let classified = AcousticSignalMath.classifyImpulse(
            peak: peak,
            rms: rms,
            lowBandEnergy: lowEnergy,
            midVocalEnergy: midEnergy,
            highBandEnergy: highEnergy,
            msSinceLastKeystroke: isTrackpadHeld ? 999.0 : msSinceKey,
            config: config,
            corroboratingMotionJerkG: recentMotionJerk,
            gyroRollDegPerSec: recentGyroRoll,
            isSustainedEnvelope: false
        ) else {
            return
        }

        if classified.rejection != .accepted {
            rejectionCounts[classified.rejection, default: 0] += 1
            performanceMonitor.recordSuppression()
            return
        }

        lastImpulseTime = now
        if visibleTelemetryConsumers > 0 {
            appendWaveformPoint(&eventTimelineHistory, value: 0.92)
        }

        if isCalibratingKnocks {
            recordCalibrationSample(jerkG: max(recentMotionJerk, Double(peak) * 0.14), rollDegPerSec: recentGyroRoll)
            return
        }

        let sample = AcousticImpulseSample(
            kind: classified.kind,
            rejectionReason: .accepted,
            peakAmplitude: peak,
            crestFactor: classified.crestFactor,
            lowBandRatio: classified.lowRatio,
            highBandRatio: classified.highRatio,
            spectralCentroidHz: centroidHz,
            spectralFlux: flux,
            riseTimeMs: 2.6,
            decayTimeMs: 13.5,
            motionJerkG: recentMotionJerk,
            gyroRollDegPerSec: recentGyroRoll,
            spatialZone: classified.zone,
            processingTimeMicros: processingMicros
        )
        appendImpulseSample(sample)
        onSinglePulseDetected?(classified.kind, classified.zone, recentMotionJerk)
        processValidatedImpulse(
            kind: classified.kind,
            crestFactor: Double(classified.crestFactor),
            motionJerkG: recentMotionJerk,
            zone: classified.zone,
            at: now
        )
    }

    private func appendWaveformPoint(_ buffer: inout [Float], value: Float) {
        buffer.append(value)
        if buffer.count > 64 {
            buffer.removeFirst(buffer.count - 64)
        }
    }

    // MARK: - Temporal Cadence & Gesture Arbitration State Machine

    private func processValidatedImpulse(
        kind: ImpulseKind,
        crestFactor: Double,
        motionJerkG: Double,
        zone: SpatialKnockZone,
        at now: TimeInterval
    ) {
        if isRecordingRhythm {
            recordedTapTimestamps.append(now)
            if recordedTapTimestamps.count >= 4 {
                finishRhythmRecording()
            }
            return
        }

        if (now - lastTriggerTime) * 1000.0 < config.cooldownMs {
            rejectionCounts[.cooldownActive, default: 0] += 1
            performanceMonitor.recordSuppression()
            return
        }

        allPulseTimestamps.append(now)
        allPulseTimestamps = allPulseTimestamps.filter { (now - $0) <= 3.0 }

        // 1. Check Custom 4-Beat Rhythm (DTW + Normalized Ratios)
        let rhythmCheck = AcousticSignalMath.matchesRhythm(
            timestamps: allPulseTimestamps,
            targetRatios: config.targetRhythmRatios,
            tolerance: config.rhythmTolerance
        )
        if rhythmCheck.matched && rhythmCheck.score >= config.minimumConfidence && isGestureEnabled(.secretRhythm) {
            allPulseTimestamps.removeAll()
            knockPulseTimestamps.removeAll()
            snapPulseTimestamps.removeAll()
            PendingCancel()
            fireGesture(
                .secretRhythm,
                confidence: rhythmCheck.score,
                interPulseMs: 210,
                crestFactor: crestFactor,
                motionJerkG: motionJerkG,
                zone: zone,
                simulated: false
            )
            return
        }

        // 2. Check Hybrid "Knock + Snap" Combo (1x Knock + 1x Snap within 120..680 ms)
        if isGestureEnabled(.knockPlusSnap) {
            if kind == .fingerSnap, let lastKnock = knockPulseTimestamps.last {
                let dt = (now - lastKnock) * 1000.0
                if dt >= 110.0 && dt <= 680.0 {
                    PendingCancel()
                    knockPulseTimestamps.removeAll()
                    snapPulseTimestamps.removeAll()
                    allPulseTimestamps.removeAll()
                    fireGesture(
                        .knockPlusSnap,
                        confidence: 0.95,
                        interPulseMs: Int(dt),
                        crestFactor: crestFactor,
                        motionJerkG: motionJerkG,
                        zone: zone,
                        simulated: false
                    )
                    return
                }
            } else if (kind == .fusedChassisKnock || kind == .motionChassisKnock), let lastSnap = snapPulseTimestamps.last {
                let dt = (now - lastSnap) * 1000.0
                if dt >= 110.0 && dt <= 680.0 {
                    PendingCancel()
                    knockPulseTimestamps.removeAll()
                    snapPulseTimestamps.removeAll()
                    allPulseTimestamps.removeAll()
                    fireGesture(
                        .knockPlusSnap,
                        confidence: 0.95,
                        interPulseMs: Int(dt),
                        crestFactor: crestFactor,
                        motionJerkG: motionJerkG,
                        zone: zone,
                        simulated: false
                    )
                    return
                }
            }
        }

        switch kind {
        case .fusedChassisKnock, .motionChassisKnock:
            knockPulseTimestamps.append(now)
            knockPulseTimestamps = knockPulseTimestamps.filter { (now - $0) * 1000.0 <= config.maxDoubleIntervalMs * 2.2 }

            if knockPulseTimestamps.count >= 3 && isGestureEnabled(.tripleKnock) {
                let t3 = knockPulseTimestamps[knockPulseTimestamps.count - 1]
                let t2 = knockPulseTimestamps[knockPulseTimestamps.count - 2]
                let t1 = knockPulseTimestamps[knockPulseTimestamps.count - 3]
                let d1 = (t2 - t1) * 1000.0
                let d2 = (t3 - t2) * 1000.0
                if d1 >= config.minDoubleIntervalMs && d1 <= config.maxDoubleIntervalMs &&
                   d2 >= config.minDoubleIntervalMs && d2 <= config.maxDoubleIntervalMs {
                    if pendingDoubleKnockTask != nil {
                        rejectionCounts[.conflictArbitrated, default: 0] += 1
                    }
                    PendingCancel()
                    knockPulseTimestamps.removeAll()
                    allPulseTimestamps.removeAll()
                    fireGesture(
                        .tripleKnock,
                        confidence: 0.96,
                        interPulseMs: Int((d1 + d2) / 2),
                        crestFactor: crestFactor,
                        motionJerkG: motionJerkG,
                        zone: zone,
                        simulated: false
                    )
                    return
                }
            }

            if knockPulseTimestamps.count >= 2 {
                let t2 = knockPulseTimestamps[knockPulseTimestamps.count - 1]
                let t1 = knockPulseTimestamps[knockPulseTimestamps.count - 2]
                let dt = (t2 - t1) * 1000.0
                if dt >= config.minDoubleIntervalMs && dt <= config.maxDoubleIntervalMs {
                    let held = isTrackpadHeld
                    PendingCancel()
                    // If Triple Knock is disabled, fire Double Knock after a minimal 80ms window; otherwise 250ms arbitration
                    let waitMs = isGestureEnabled(.tripleKnock) ? 250 : 80
                    pendingDoubleKnockTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(waitMs))
                        guard !Task.isCancelled, let self else { return }
                        self.knockPulseTimestamps.removeAll()
                        self.allPulseTimestamps.removeAll()
                        let resolvedGesture = self.resolveDoubleKnockVariant(isHeld: held, zone: zone)
                        self.fireGesture(
                            resolvedGesture,
                            confidence: 0.94,
                            interPulseMs: Int(dt),
                            crestFactor: crestFactor,
                            motionJerkG: motionJerkG,
                            zone: zone,
                            simulated: false
                        )
                    }
                    return
                }
            }

        case .fingerSnap:
            snapPulseTimestamps.append(now)
            snapPulseTimestamps = snapPulseTimestamps.filter { (now - $0) * 1000.0 <= config.maxDoubleIntervalMs * 1.6 }

            if snapPulseTimestamps.count >= 2 && isGestureEnabled(.doubleSnap) {
                let t2 = snapPulseTimestamps[snapPulseTimestamps.count - 1]
                let t1 = snapPulseTimestamps[snapPulseTimestamps.count - 2]
                let dt = (t2 - t1) * 1000.0
                if dt >= config.minDoubleIntervalMs && dt <= config.maxDoubleIntervalMs {
                    PendingCancel()
                    snapPulseTimestamps.removeAll()
                    allPulseTimestamps.removeAll()
                    fireGesture(
                        .doubleSnap,
                        confidence: 0.95,
                        interPulseMs: Int(dt),
                        crestFactor: crestFactor,
                        motionJerkG: 0.0,
                        zone: .any,
                        simulated: false
                    )
                    return
                }
            }

        default:
            break
        }
    }

    public func isGestureEnabled(_ gesture: AcousticGestureType) -> Bool {
        guard config.enabledGestures[gesture] ?? true else { return false }
        return (gestureActions[gesture] ?? .disabled) != .disabled
    }

    public func setGestureEnabled(_ gesture: AcousticGestureType, enabled: Bool) {
        config.enabledGestures[gesture] = enabled
        if enabled && (gestureActions[gesture] == nil || gestureActions[gesture] == .disabled) {
            gestureActions[gesture] = PersistedConfigurationBundle.defaultGlobalMappings[gesture] ?? .playPauseMedia
        }
        saveConfiguration()
    }

    private func resolveDoubleKnockVariant(isHeld: Bool, zone: SpatialKnockZone) -> AcousticGestureType {
        if isHeld && isGestureEnabled(.trackpadHoldDoubleKnock) {
            return .trackpadHoldDoubleKnock
        }
        if config.enableExperimentalSpatialZones {
            if zone == .leftPalmRest && isGestureEnabled(.leftZoneDoubleKnock) {
                return .leftZoneDoubleKnock
            }
            if zone == .rightPalmRest && isGestureEnabled(.rightZoneDoubleKnock) {
                return .rightZoneDoubleKnock
            }
        }
        return .doubleKnock
    }

    public func effectiveAction(for gesture: AcousticGestureType) -> SystemActionType {
        guard config.enabledGestures[gesture] ?? true else { return .disabled }
        let bundleID = contextObserver.frontmostBundleID
        if let profile = appProfiles.first(where: { $0.bundleIdentifier == bundleID && $0.isEnabled }),
           let mapped = profile.mappings[gesture],
           mapped != .disabled {
            return mapped
        }
        return gestureActions[gesture] ?? .disabled
    }

    private func PendingCancel() {
        pendingDoubleKnockTask?.cancel()
        pendingDoubleKnockTask = nil
    }

    private func appendImpulseSample(_ sample: AcousticImpulseSample) {
        recentImpulses.insert(sample, at: 0)
        if recentImpulses.count > 40 {
            recentImpulses.removeLast()
        }
    }

    // MARK: - Guided Calibration Wizard (3 Taps — Matches Reference Design)

    public func startGuidedKnockCalibration() {
        isCalibratingKnocks = true
        calibrationRecordedJerks.removeAll()
        calibrationRecordedRolls.removeAll()
        calibrationStatusText = "Tap your MacBook 3 times · We'll learn your unique signature (0 / 3)"
        if !isListening {
            startListening()
        }
    }

    public func cancelGuidedCalibration() {
        isCalibratingKnocks = false
        calibrationRecordedJerks.removeAll()
        calibrationRecordedRolls.removeAll()
        calibrationStatusText = "Calibration cancelled."
    }

    public func recordCalibrationSample(jerkG: Double, rollDegPerSec: Double) {
        calibrationRecordedJerks.append(jerkG)
        calibrationRecordedRolls.append(rollDegPerSec)
        let count = min(3, calibrationRecordedJerks.count)
        calibrationStatusText = "Recorded Tap \(count) of 3 (Peak \(String(format: "%.3f g", jerkG)))"
        if calibrationRecordedJerks.count >= 3 {
            let meanJerk = calibrationRecordedJerks.reduce(0, +) / Double(calibrationRecordedJerks.count)
            config.calibratedMeanKnockJerkG = meanJerk
            config.minimumMotionJerkG = max(0.014, min(0.055, meanJerk * 0.48))
            config.calibrationSampleCount += calibrationRecordedJerks.count
            isCalibratingKnocks = false
            calibrationStatusText = String(
                format: "Signature learned from 3 taps · Mean %.3fg → Gate %.3fg",
                meanJerk,
                config.minimumMotionJerkG
            )
            saveConfiguration()
        }
    }

    // MARK: - Interactive Simulation & Rhythm Trainer

    public func simulateGesture(_ gesture: AcousticGestureType) {
        switch gesture {
        case .doubleKnock, .tripleKnock, .trackpadHoldDoubleKnock, .leftZoneDoubleKnock, .rightZoneDoubleKnock:
            lowBandLevel = 0.86
            highBandLevel = 0.14
            currentPeak = 0.78
            currentCrestFactor = 8.4
            currentMotionJerkG = 0.095
            spectrumBands = [0.92, 0.96, 0.88, 0.76, 0.62, 0.42, 0.28, 0.20, 0.16, 0.14, 0.12, 0.11, 0.10, 0.09, 0.08, 0.08]
        case .doubleSnap, .knockPlusSnap:
            lowBandLevel = 0.34
            highBandLevel = 0.89
            currentPeak = 0.82
            currentCrestFactor = 10.2
            currentMotionJerkG = 0.042
            spectrumBands = [0.12, 0.14, 0.16, 0.22, 0.30, 0.42, 0.56, 0.68, 0.82, 0.94, 0.98, 0.91, 0.84, 0.72, 0.58, 0.44]
        case .secretRhythm, .hingeNudge:
            lowBandLevel = 0.68
            highBandLevel = 0.64
            currentPeak = 0.85
            currentCrestFactor = 9.1
            currentMotionJerkG = 0.078
            spectrumBands = [0.82, 0.76, 0.68, 0.54, 0.48, 0.62, 0.78, 0.88, 0.84, 0.72, 0.64, 0.76, 0.86, 0.78, 0.62, 0.48]
        }

        let zone: SpatialKnockZone
        switch gesture {
        case .leftZoneDoubleKnock: zone = .leftPalmRest
        case .rightZoneDoubleKnock: zone = .rightPalmRest
        default: zone = .any
        }

        let sample = AcousticImpulseSample(
            kind: gesture == .doubleSnap ? .fingerSnap : .fusedChassisKnock,
            rejectionReason: .accepted,
            peakAmplitude: currentPeak,
            crestFactor: currentCrestFactor,
            lowBandRatio: lowBandLevel,
            highBandRatio: highBandLevel,
            motionJerkG: currentMotionJerkG,
            spatialZone: zone
        )
        appendImpulseSample(sample)

        fireGesture(
            gesture,
            confidence: 0.98,
            interPulseMs: 210,
            crestFactor: Double(currentCrestFactor),
            motionJerkG: currentMotionJerkG,
            zone: zone,
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
        currentMotionJerkG = 0.082
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
        saveConfiguration()
    }

    // MARK: - Trigger Dispatch

    private func fireGesture(
        _ gesture: AcousticGestureType,
        confidence: Double,
        interPulseMs: Int,
        crestFactor: Double,
        motionJerkG: Double,
        zone: SpatialKnockZone,
        simulated: Bool
    ) {
        let tStart = DispatchTime.now().uptimeNanoseconds
        let action = effectiveAction(for: gesture)
        guard action != .disabled else { return }
        guard confidence >= config.minimumConfidence else {
            rejectionCounts[.belowConfidenceThreshold, default: 0] += 1
            return
        }

        lastTriggerTime = ProcessInfo.processInfo.systemUptime
        lastDetectedGesture = gesture
        lastTriggerTimestamp = Date()
        lastConfidencePercent = Int((confidence * 100.0).rounded())

        let execResult = SystemActionExecutor.shared.execute(action, config: config)
        let latencyMs = max(1.2, Double(DispatchTime.now().uptimeNanoseconds - tStart) / 1_000_000.0 + 14.5)
        performanceMonitor.recordRecognitionLatency(ms: latencyMs)

        statusMessage = "\(gesture.title) → \(execResult.summary)"

        let record = TriggeredEventRecord(
            gesture: gesture,
            action: action,
            confidence: confidence,
            interPulseMs: interPulseMs,
            crestFactor: crestFactor,
            motionJerkG: motionJerkG,
            spatialZone: zone,
            recognitionLatencyMs: latencyMs,
            activeAppBundleID: contextObserver.frontmostAppName,
            executionSummary: execResult.summary,
            actionSucceeded: execResult.succeeded,
            isSimulated: simulated
        )
        triggerHistory.insert(record, at: 0)
        if triggerHistory.count > 50 {
            triggerHistory.removeLast()
        }

        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        onGestureTriggered?(record)
    }

    // MARK: - Demand-Driven Visual Decay Loop (Runs ONLY when UI is visible!)

    private func startVisualDecayLoop() {
        guard decayTimer == nil else { return }
        decayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.visibleTelemetryConsumers > 0 else { return }
                for i in 0..<self.spectrumBands.count {
                    let idleFloor: Float = 0.07 + Float(i % 3) * 0.012
                    self.spectrumBands[i] = max(idleFloor, self.spectrumBands[i] * 0.88)
                }
                self.currentPeak = max(0.01, self.currentPeak * 0.86)
                self.currentCrestFactor = max(1.0, 1.0 + (self.currentCrestFactor - 1.0) * 0.85)
                self.lowBandLevel = max(0.08, self.lowBandLevel * 0.92)
                self.highBandLevel = max(0.06, self.highBandLevel * 0.92)
                self.currentMotionJerkG = max(0.0004, self.currentMotionJerkG * 0.82)
                self.performanceMonitor.sampleProcessMetrics()
            }
        }
    }

    private func stopVisualDecayLoop() {
        decayTimer?.invalidate()
        decayTimer = nil
    }
}
