import SwiftUI

/// Part 4.1: Menu Bar Companion — Persistent macOS 27 Liquid Glass interface.
/// Automatically registers/unregisters telemetry visibility so zero rendering occurs when closed.
public struct ControlCenterMenuBarView: View {
    @Bindable var engine: AcousticImpulseEngine
    let onOpenSettings: () -> Void
    let onStartCalibration: () -> Void
    let onTriggerAction: (AcousticGestureType) -> Void
    let onTogglePrivacyShield: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassMorphNamespace

    public init(
        engine: AcousticImpulseEngine,
        onOpenSettings: @escaping () -> Void,
        onStartCalibration: @escaping () -> Void = {},
        onTriggerAction: @escaping (AcousticGestureType) -> Void,
        onTogglePrivacyShield: @escaping () -> Void
    ) {
        self.engine = engine
        self.onOpenSettings = onOpenSettings
        self.onStartCalibration = onStartCalibration
        self.onTriggerAction = onTriggerAction
        self.onTogglePrivacyShield = onTogglePrivacyShield
    }

    public var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                headerHeroModule
                sensorStatusAndModalityStrip
                liveSpectralStripModule
                bentoGestureGridModule
                sensitivityModule
                recentImpulseFooterModule
                controlCenterActionBar
            }
            .padding(14)
        }
        .frame(width: MacOS27Theme.controlCenterWidth)
        .background(
            ZStack {
                NativeAppKitGlassSurface(
                    cornerRadius: MacOS27Theme.moduleCornerRadius,
                    tintColor: nil,
                    isInteractive: false
                )
                LinearGradient(
                    colors: [
                        MacOS27Theme.electricCyan.opacity(engine.isListening ? 0.07 : 0.02),
                        Color.clear,
                        MacOS27Theme.systemIndigo.opacity(engine.isListening ? 0.05 : 0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .onAppear {
            engine.registerVisibleTelemetryConsumer()
        }
        .onDisappear {
            engine.unregisterVisibleTelemetryConsumer()
        }
    }

    // MARK: - 1. Top Control Center Hero Pill

    private var headerHeroModule: some View {
        HStack(spacing: 12) {
            Button {
                if reduceMotion {
                    engine.toggleListening()
                } else {
                    withAnimation(.spring(duration: 0.30, bounce: 0.18)) {
                        engine.toggleListening()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            engine.isListening
                                ? LinearGradient(
                                    colors: [MacOS27Theme.systemBlue, MacOS27Theme.electricCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.secondary.opacity(0.28), Color.secondary.opacity(0.16)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.12)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.75
                                )
                        )

                    Image(systemName: engine.isListening ? "waveform.badge.magnifyingglass" : "pause.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.isListening ? "Pause Physical Sensing" : "Resume Physical Sensing")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("KnockKnock X")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.labelPrimary)

                    Text(engine.activeProfileName)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.electricCyan)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(MacOS27Theme.electricCyan.opacity(0.15))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(MacOS27Theme.electricCyan.opacity(0.40), lineWidth: 0.5)
                                )
                        )
                        .lineLimit(1)
                }

                Text(engine.statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Toggle("Sensing Active", isOn: Binding(
                get: { engine.isListening },
                set: { newValue in
                    if newValue != engine.isListening {
                        engine.toggleListening()
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .macOS27GlassCard(
            cornerRadius: MacOS27Theme.pillCornerRadius,
            tint: engine.isListening ? MacOS27Theme.systemBlue : nil,
            isActive: engine.isListening,
            isInteractive: true
        )
        .glassEffectID("heroModule", in: glassMorphNamespace)
    }

    // MARK: - 1b. Hardware Sensor Availability & Modality Strip

    private var sensorStatusAndModalityStrip: some View {
        HStack(spacing: 6) {
            sensorBadge(
                label: "BMI286 200Hz",
                active: engine.motionService.isRunning || engine.capabilities.hasSPUAccelerometer,
                symbol: "gyroscope"
            )
            sensorBadge(
                label: engine.motionService.lidAngleDegrees > 0
                    ? "Lid \(Int(engine.motionService.lidAngleDegrees))°"
                    : "Lid Sensor",
                active: engine.capabilities.hasLidAngleSensor,
                symbol: "laptopcomputer"
            )
            sensorBadge(
                label: engine.config.modalityMode == .accelerometerPrimary ? "Mic Off" : "48kHz Mic",
                active: engine.config.modalityMode != .accelerometerPrimary && engine.microphoneAuthorized,
                symbol: engine.config.modalityMode == .accelerometerPrimary ? "mic.slash" : "mic.fill"
            )
            Spacer(minLength: 2)
            Menu {
                ForEach(SensorModalityMode.allCases) { mode in
                    Button {
                        engine.config.modalityMode = mode
                        engine.saveConfiguration()
                        if engine.isListening {
                            engine.startListening()
                        }
                    } label: {
                        Label(mode.title, systemImage: mode == .accelerometerPrimary ? "gyroscope" : "waveform")
                    }
                }
            } label: {
                Text(engine.config.modalityMode == .accelerometerPrimary ? "Motion Only" : "Fusion")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.labelPrimary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .macOS27GlassCard(
            cornerRadius: 11,
            tint: nil,
            isActive: false,
            isInteractive: true
        )
    }

    private func sensorBadge(label: String, active: Bool, symbol: String) -> some View {
        HStack(spacing: 3.5) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(active ? MacOS27Theme.listeningGreen : Color.secondary)
            Text(label)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(active ? MacOS27Theme.labelPrimary : MacOS27Theme.labelTertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(active ? MacOS27Theme.listeningGreen.opacity(0.12) : Color.secondary.opacity(0.08))
        )
    }

    // MARK: - 2. Real-Time 16-Band Spectral & Motion Jerk Strip

    private var liveSpectralStripModule: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(engine.isListening ? MacOS27Theme.listeningGreen : Color.secondary.opacity(0.45))
                    .frame(width: 6.5, height: 6.5)

                Text("MOTION JERK & ACOUSTIC TRANSIENTS")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(MacOS27Theme.labelSecondary)

                Spacer()

                if engine.isTypingSuppressed {
                    Label("Input Guard", systemImage: "keyboard.badge.ellipsis")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(MacOS27Theme.knockAmber)
                } else {
                    Text(String(format: "Jerk %.3fg · Crest %.1fx", engine.currentMotionJerkG, Double(engine.currentCrestFactor)))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(engine.spectrumBands.enumerated()), id: \.offset) { idx, level in
                    let normalized = Double(min(1.0, max(0.08, level)))
                    let isChassisBand = idx < 6
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isChassisBand
                                    ? [MacOS27Theme.knockAmber, MacOS27Theme.systemBlue]
                                    : [MacOS27Theme.electricCyan, MacOS27Theme.snapTeal],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: CGFloat(6.0 + normalized * 26.0))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 33, alignment: .bottom)
            .padding(.horizontal, 4)

            HStack(spacing: 10) {
                subBandMeter(
                    title: "Chassis Motion / Knock",
                    value: Double(max(engine.lowBandLevel, Float(min(1.0, engine.currentMotionJerkG * 8.0)))),
                    tint: MacOS27Theme.knockAmber
                )
                subBandMeter(
                    title: "Air Transient / Snap",
                    value: Double(engine.highBandLevel),
                    tint: MacOS27Theme.snapTeal
                )
            }
        }
        .padding(11)
        .macOS27GlassCard(
            cornerRadius: MacOS27Theme.tileCornerRadius,
            tint: nil,
            isActive: false,
            isInteractive: true
        )
    }

    private func subBandMeter(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                Spacer()
                Text("\(Int((min(1.0, max(0.0, value)) * 100.0).rounded()))%")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MacOS27Theme.labelPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                    Capsule(style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, max(0.0, value)))))
                }
            }
            .frame(height: 4.5)
        }
    }

    // MARK: - 3. 2x2 Bento Gesture Grid (Core 4 Gestures)

    private var bentoGestureGridModule: some View {
        let primaryFour: [AcousticGestureType] = [.doubleKnock, .doubleSnap, .tripleKnock, .secretRhythm]
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(primaryFour) { gesture in
                bentoGestureTile(for: gesture)
            }
        }
    }

    private func bentoGestureTile(for gesture: AcousticGestureType) -> some View {
        let currentAction = engine.effectiveAction(for: gesture)
        let isEnabled = currentAction != .disabled
        let accentColor = accentColor(for: gesture)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? accentColor.opacity(0.22) : Color.secondary.opacity(0.12))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isEnabled ? accentColor.opacity(0.55) : Color.white.opacity(0.14),
                                    lineWidth: 0.65
                                )
                        )

                    Image(systemName: gesture.symbolName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isEnabled ? accentColor : MacOS27Theme.labelSecondary)
                }

                Spacer()

                Button {
                    onTriggerAction(gesture)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(MacOS27Theme.labelPrimary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
                .help("Test \(gesture.title) (\(currentAction.title))")
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(gesture.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.labelPrimary)
                    .lineLimit(1)

                Text(gesture.frequencyBadge)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(MacOS27Theme.labelTertiary)
                    .lineLimit(1)
            }

            Menu {
                ForEach(SystemActionType.allCases) { actionOption in
                    Button {
                        engine.gestureActions[gesture] = actionOption
                        engine.saveConfiguration()
                    } label: {
                        Label(actionOption.title, systemImage: actionOption.symbolName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentAction.symbolName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isEnabled ? accentColor : MacOS27Theme.labelSecondary)

                    Text(currentAction.shortTitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(MacOS27Theme.labelPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(MacOS27Theme.labelTertiary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .macOS27GlassCard(
            cornerRadius: MacOS27Theme.tileCornerRadius,
            tint: isEnabled ? accentColor : nil,
            isActive: isEnabled,
            isInteractive: true
        )
    }

    // MARK: - 4. Sensitivity & Reliability Slider Pill

    private var sensitivityModule: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Impact Sensitivity", systemImage: "slider.horizontal.below.waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.labelPrimary)

                Spacer()

                Text(String(format: "%d%% (Gate %.3fg)", Int((engine.config.sensitivity * 100).rounded()), engine.config.effectiveMotionJerkGateG))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MacOS27Theme.electricCyan)
            }

            Slider(
                value: Binding(
                    get: { Double(engine.config.sensitivity) },
                    set: { newVal in
                        engine.config.sensitivity = Float(newVal)
                        engine.saveConfiguration()
                    }
                ),
                in: 0.15...0.95
            )
            .controlSize(.small)
            .tint(MacOS27Theme.systemBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .macOS27GlassCard(
            cornerRadius: MacOS27Theme.pillCornerRadius,
            tint: nil,
            isActive: false,
            isInteractive: true
        )
    }

    // MARK: - 5. Recent Triggered Action Strip

    private var recentImpulseFooterModule: some View {
        HStack(spacing: 8) {
            if let latest = engine.triggerHistory.first {
                Image(systemName: latest.actionSucceeded ? latest.action.symbolName : "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(latest.actionSucceeded ? MacOS27Theme.electricCyan : MacOS27Theme.knockAmber)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill((latest.actionSucceeded ? MacOS27Theme.electricCyan : MacOS27Theme.knockAmber).opacity(0.16))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(latest.gesture.title) → \(latest.action.shortTitle)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MacOS27Theme.labelPrimary)
                        .lineLimit(1)

                    Text(String(format: "%.0f%% conf · %.0f ms latency · %@", latest.confidence * 100, latest.recognitionLatencyMs, latest.spatialZone.rawValue))
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "hand.point.up.braille.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                    .frame(width: 24, height: 24)

                Text("Click Start Sensing, then double-knock on your MacBook palm rest.")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 2)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .macOS27GlassCard(
            cornerRadius: MacOS27Theme.pillCornerRadius,
            tint: nil,
            isActive: false,
            isInteractive: false
        )
    }

    // MARK: - 6. Bottom Action Bar (Calibrate, Studio/Lab, Quit)

    private var controlCenterActionBar: some View {
        HStack(spacing: 8) {
            Button {
                onStartCalibration()
                onOpenSettings()
            } label: {
                Label("Calibrate", systemImage: "scope")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.small)

            Button {
                onOpenSettings()
            } label: {
                Label("Gesture Studio…", systemImage: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(MacOS27Theme.systemBlue)
            .controlSize(.small)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help("Quit KnockKnock X")
        }
    }

    private func accentColor(for gesture: AcousticGestureType) -> Color {
        switch gesture {
        case .doubleKnock, .leftZoneDoubleKnock, .rightZoneDoubleKnock:
            return MacOS27Theme.knockAmber
        case .doubleSnap:
            return MacOS27Theme.snapTeal
        case .tripleKnock, .trackpadHoldDoubleKnock:
            return MacOS27Theme.systemBlue
        case .secretRhythm, .hingeNudge:
            return MacOS27Theme.rhythmPurple
        }
    }
}
