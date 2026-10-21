import SwiftUI

/// Sidebar panes modeled after macOS 27 System Settings.
public enum KnockKnockSettingsPane: String, CaseIterable, Identifiable {
    case acousticEngine = "Acoustic Engine"
    case gestureMappings = "Gesture Mappings"
    case secretRhythmStudio = "Secret Rhythm Studio"
    case liveTelemetry = "Impulse Telemetry"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .acousticEngine:
            return "Spectral FFT, Crest Factor & Keystroke Guard"
        case .gestureMappings:
            return "Double Knock, Snap, Triple Knock & Shortcuts"
        case .secretRhythmStudio:
            return "Record & Test Custom 4-Beat Knock Cadences"
        case .liveTelemetry:
            return "Real-Time Impulse Classification & Event Log"
        }
    }

    public var symbolName: String {
        switch self {
        case .acousticEngine:
            return "waveform.badge.magnifyingglass"
        case .gestureMappings:
            return "hand.tap.fill"
        case .secretRhythmStudio:
            return "metronome.fill"
        case .liveTelemetry:
            return "chart.xyaxis.line"
        }
    }

    public var badgeGradient: [Color] {
        switch self {
        case .acousticEngine:
            return [MacOS27Theme.systemBlue, MacOS27Theme.electricCyan]
        case .gestureMappings:
            return [MacOS27Theme.knockAmber, Color(red: 1.0, green: 0.38, blue: 0.22)]
        case .secretRhythmStudio:
            return [MacOS27Theme.rhythmPurple, MacOS27Theme.systemIndigo]
        case .liveTelemetry:
            return [MacOS27Theme.listeningGreen, MacOS27Theme.snapTeal]
        }
    }
}

/// Authentic macOS 27 System Settings window with Liquid Glass cards, squircle sidebar badges,
/// and interactive acoustic calibration & rhythm recording tools.
public struct SettingsWindowView: View {
    @Bindable var engine: AcousticImpulseEngine
    let onTriggerAction: (AcousticGestureType) -> Void
    let onTogglePrivacyShield: () -> Void

    @State private var selectedPane: KnockKnockSettingsPane = .acousticEngine

    public init(
        engine: AcousticImpulseEngine,
        onTriggerAction: @escaping (AcousticGestureType) -> Void,
        onTogglePrivacyShield: @escaping () -> Void
    ) {
        self.engine = engine
        self.onTriggerAction = onTriggerAction
        self.onTogglePrivacyShield = onTogglePrivacyShield
    }

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 225, ideal: 240, max: 265)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailHeaderBanner
                    switch selectedPane {
                    case .acousticEngine:
                        acousticEnginePane
                    case .gestureMappings:
                        gestureMappingsPane
                    case .secretRhythmStudio:
                        secretRhythmStudioPane
                    case .liveTelemetry:
                        liveTelemetryPane
                    }
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    colors: [
                        MacOS27Theme.systemBlue.opacity(0.05),
                        Color.clear,
                        MacOS27Theme.systemIndigo.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .containerBackground(.ultraThinMaterial, for: .window)
        .frame(
            minWidth: MacOS27Theme.settingsWindowWidth,
            minHeight: MacOS27Theme.settingsWindowHeight
        )
    }

    // MARK: - Sidebar (macOS 27 System Settings Style)

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App Identity Card at top of Sidebar
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MacOS27Theme.systemBlue, MacOS27Theme.electricCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.75)
                        )
                        .shadow(color: MacOS27Theme.systemBlue.opacity(0.35), radius: 6, y: 2)

                    Image(systemName: "waveform.and.magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("KnockKnock")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.labelPrimary)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(engine.isListening ? MacOS27Theme.listeningGreen : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(engine.isListening ? "Acoustic DSP Active" : "Engine Paused")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 4)

            List(KnockKnockSettingsPane.allCases, selection: $selectedPane) { pane in
                HStack(spacing: 10) {
                    MacOS27SettingsIconBadge(
                        symbol: pane.symbolName,
                        gradientColors: pane.badgeGradient
                    )

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(pane.rawValue)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(MacOS27Theme.labelPrimary)
                        Text(pane.subtitle)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 3)
                .tag(pane)
            }
            .listStyle(.sidebar)

            // Quick Simulation Bar at Bottom of Sidebar
            VStack(alignment: .leading, spacing: 7) {
                Text("QUICK HARDWARE SIMULATOR")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(MacOS27Theme.labelTertiary)

                HStack(spacing: 6) {
                    Button {
                        onTriggerAction(.doubleKnock)
                    } label: {
                        Label("2× Knock", systemImage: "hand.tap.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)

                    Button {
                        onTriggerAction(.doubleSnap)
                    } label: {
                        Label("2× Snap", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Top Detail Header Banner

    private var detailHeaderBanner: some View {
        HStack(spacing: 14) {
            MacOS27SettingsIconBadge(
                symbol: selectedPane.symbolName,
                gradientColors: selectedPane.badgeGradient
            )
            .scaleEffect(1.2)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedPane.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.labelPrimary)

                Text(selectedPane.subtitle)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
            }

            Spacer()

            Button {
                engine.toggleListening()
            } label: {
                Label(
                    engine.isListening ? "Listening Live" : "Start Listening",
                    systemImage: engine.isListening ? "waveform.circle.fill" : "play.circle.fill"
                )
                .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(engine.isListening ? MacOS27Theme.systemBlue : .secondary)
        }
        .padding(16)
        .macOS27GlassCard(
            cornerRadius: MacOS27Theme.tileCornerRadius,
            tint: MacOS27Theme.systemBlue,
            isActive: engine.isListening,
            isInteractive: true
        )
    }

    // MARK: - Pane 1: Acoustic Engine & Calibration

    private var acousticEnginePane: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Real-time Spectral Visualizer & Sub-Band Energy Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Real-Time Unibody Resonance & Air Transient Analyzer", systemImage: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.labelPrimary)

                    Spacer()

                    Text(String(format: "Peak %.3f  •  Crest %.1fx  •  Gate %.3f", engine.currentPeak, engine.currentCrestFactor, engine.config.amplitudeGate))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(engine.spectrumBands.enumerated()), id: \.offset) { idx, level in
                        let normalized = Double(min(1.0, max(0.06, level)))
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: idx < 6
                                            ? [MacOS27Theme.knockAmber, MacOS27Theme.systemBlue]
                                            : [MacOS27Theme.electricCyan, MacOS27Theme.snapTeal],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: CGFloat(8.0 + normalized * 62.0))
                                .frame(maxWidth: .infinity)
                                .animation(.interpolatingSpring(stiffness: 260, damping: 19), value: level)

                            Text(bandLabel(for: idx))
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(MacOS27Theme.labelTertiary)
                        }
                    }
                }
                .frame(height: 86, alignment: .bottom)
                .padding(.vertical, 4)

                HStack(spacing: 12) {
                    calibrationMetricPill(
                        title: "Chassis Thud Band (80–450 Hz)",
                        value: "\(Int((engine.lowBandLevel * 100).rounded()))%",
                        subtitle: "Dominant on aluminum unibody knocks",
                        tint: MacOS27Theme.knockAmber
                    )
                    calibrationMetricPill(
                        title: "Air Snap Band (2.2–4.8 kHz)",
                        value: "\(Int((engine.highBandLevel * 100).rounded()))%",
                        subtitle: "Dominant on crisp finger snaps",
                        tint: MacOS27Theme.snapTeal
                    )
                }
            }
            .padding(16)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

            // DSP Sliders & Keystroke Immunity Card
            VStack(alignment: .leading, spacing: 14) {
                Text("DSP Thresholds & False-Positive Protection")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.labelPrimary)

                sliderRow(
                    title: "Impulse Sensitivity",
                    subtitle: "Higher sensitivity detects lighter fingertip taps from further away",
                    valueText: "\(Int((engine.config.sensitivity * 100).rounded()))%",
                    value: Binding(
                        get: { Double(engine.config.sensitivity) },
                        set: { engine.config.sensitivity = Float($0) }
                    ),
                    range: 0.15...0.95
                )

                Divider().opacity(0.25)

                sliderRow(
                    title: "Minimum Crest Factor (Peak / RMS)",
                    subtitle: "Rejects continuous human speech and desk music while passing sharp physical impulses",
                    valueText: String(format: "%.1fx", engine.config.minimumCrestFactor),
                    value: Binding(
                        get: { Double(engine.config.minimumCrestFactor) },
                        set: { engine.config.minimumCrestFactor = Float($0) }
                    ),
                    range: 2.2...8.0
                )

                Divider().opacity(0.25)

                sliderRow(
                    title: "Keystroke & Trackpad Immunity Window",
                    subtitle: "Queries CGEventSource keyboard/mouse state to ignore vibrations while typing",
                    valueText: "\(Int(engine.config.typingSuppressionWindowMs.rounded())) ms",
                    value: Binding(
                        get: { engine.config.typingSuppressionWindowMs },
                        set: { engine.config.typingSuppressionWindowMs = $0 }
                    ),
                    range: 40.0...450.0
                )
            }
            .padding(16)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)
        }
    }

    // MARK: - Pane 2: Gesture & Action Mappings

    private var gestureMappingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(AcousticGestureType.allCases) { gesture in
                let selectedAction = engine.gestureActions[gesture] ?? .disabled
                HStack(spacing: 14) {
                    MacOS27SettingsIconBadge(
                        symbol: gesture.symbolName,
                        gradientColors: [accentColor(for: gesture), MacOS27Theme.systemIndigo]
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(gesture.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MacOS27Theme.labelPrimary)

                            Text(gesture.frequencyBadge)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(accentColor(for: gesture))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(accentColor(for: gesture).opacity(0.15))
                                )
                        }

                        Text(gesture.subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { engine.gestureActions[gesture] ?? .disabled },
                        set: { engine.gestureActions[gesture] = $0 }
                    )) {
                        ForEach(SystemActionType.allCases) { action in
                            Label(action.title, systemImage: action.symbolName)
                                .tag(action)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 215)

                    Button {
                        onTriggerAction(gesture)
                    } label: {
                        Label("Trigger Now", systemImage: "bolt.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(selectedAction == .disabled)
                }
                .padding(14)
                .macOS27GlassCard(
                    cornerRadius: MacOS27Theme.tileCornerRadius,
                    tint: selectedAction != .disabled ? accentColor(for: gesture) : nil,
                    isActive: selectedAction != .disabled,
                    isInteractive: true
                )
            }

            // Custom macOS Shortcut Name Card + Privacy Shield Test Card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("macOS Shortcuts Integration", systemImage: "square.stack.3d.up.fill")
                        .font(.system(size: 12.5, weight: .semibold))

                    Text("When a gesture is mapped to “Run macOS Shortcut”, KnockKnock invokes `/usr/bin/shortcuts run` with this name:")
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS27Theme.labelSecondary)

                    TextField("Shortcut Name (e.g. Focus Mode)", text: $engine.customShortcutName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Instant Liquid Glass Privacy Shield", systemImage: "eye.slash.circle.fill")
                        .font(.system(size: 12.5, weight: .semibold))

                    Text("Covers your workspace in a full-screen macOS 27 `NSGlassEffectView` refraction shield (`Esc` or click to dismiss).")
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS27Theme.labelSecondary)

                    Button {
                        onTogglePrivacyShield()
                    } label: {
                        Label("Toggle Full-Screen Privacy Shield", systemImage: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(MacOS27Theme.rhythmPurple)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)
            }
        }
    }

    // MARK: - Pane 3: Secret Rhythm Studio

    private var secretRhythmStudioPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("4-Beat Tempo-Invariant Cadence Signature")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("KnockKnock normalizes the 3 inter-tap intervals between 4 knocks (\(engine.rhythmPatternDescription)) so your secret rhythm works whether tapped fast or slow.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                    }

                    Spacer()

                    Button {
                        engine.config.targetRhythmRatios = [1.0, 0.52, 0.52]
                        engine.rhythmPatternDescription = "4-Beat Classic (1.0× · 0.52× · 0.52×)"
                    } label: {
                        Label("Reset Default", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                // Visual Interval Proportion Bars
                HStack(spacing: 10) {
                    ForEach(Array(engine.config.targetRhythmRatios.enumerated()), id: \.offset) { index, ratio in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Interval \(index + 1) (Beat \(index + 1) → \(index + 2))")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(MacOS27Theme.labelSecondary)
                                Spacer()
                                Text(String(format: "%.2f×", ratio))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(MacOS27Theme.rhythmPurple)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule(style: .continuous)
                                        .fill(Color.primary.opacity(0.10))
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [MacOS27Theme.rhythmPurple, MacOS27Theme.electricCyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(8, geo.size.width * CGFloat(min(1.0, max(0.08, ratio / 1.5)))))
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(12)
                        .macOS27GlassCard(cornerRadius: 12)
                    }
                }

                // Interactive Recording Studio Pad
                HStack(spacing: 14) {
                    Button {
                        engine.recordManualRhythmBeat()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: engine.isRecordingRhythm ? "hand.tap.fill" : "record.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(
                                engine.isRecordingRhythm
                                    ? "Tap Next Beat (\(engine.recordedTapTimestamps.count) / 4)"
                                    : "Record 4-Beat Rhythm by Tapping Here"
                            )
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(engine.isRecordingRhythm ? MacOS27Theme.knockAmber : MacOS27Theme.rhythmPurple)

                    if engine.isRecordingRhythm {
                        Button("Finish Early") {
                            engine.finishRhythmRecording()
                        }
                        .buttonStyle(.glass)
                    }

                    Spacer()

                    Button {
                        onTriggerAction(.secretRhythm)
                    } label: {
                        Label("Simulate Secret Rhythm", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(16)
            .macOS27GlassCard(
                cornerRadius: MacOS27Theme.tileCornerRadius,
                tint: MacOS27Theme.rhythmPurple,
                isActive: engine.isRecordingRhythm,
                isInteractive: true
            )
        }
    }

    // MARK: - Pane 4: Live Impulse & Event Telemetry

    private var liveTelemetryPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Triggered Gestures (\(engine.triggerHistory.count))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button {
                    engine.triggerHistory.removeAll()
                    engine.recentImpulses.removeAll()
                } label: {
                    Label("Clear Telemetry", systemImage: "trash")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            if engine.triggerHistory.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                    Text("No gestures triggered yet in this session. Knock twice on your MacBook or click “Trigger Now” to populate live telemetry.")
                        .font(.system(size: 12))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)
            } else {
                VStack(spacing: 8) {
                    ForEach(engine.triggerHistory.prefix(6)) { event in
                        HStack(spacing: 12) {
                            Image(systemName: event.gesture.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accentColor(for: event.gesture))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(accentColor(for: event.gesture).opacity(0.16))
                                )

                            VStack(alignment: .leading, spacing: 1.5) {
                                Text("\(event.gesture.title) → \(event.action.title)")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Confidence \(Int((event.confidence * 100).rounded()))%  •  Gap \(event.interPulseMs) ms  •  Crest \(String(format: "%.1fx", event.crestFactor))")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(MacOS27Theme.labelSecondary)
                            }

                            Spacer()

                            Text(event.timestamp, style: .time)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(MacOS27Theme.labelTertiary)
                        }
                        .padding(10)
                        .macOS27GlassCard(cornerRadius: 12)
                    }
                }
            }

            Text("Classified Acoustic Impulses (\(engine.recentImpulses.count))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.top, 4)

            if engine.recentImpulses.isEmpty {
                Text("Waiting for physical chassis knocks or finger snaps…")
                    .font(.system(size: 12))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)
            } else {
                VStack(spacing: 6) {
                    ForEach(engine.recentImpulses.prefix(10)) { sample in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(sampleColor(for: sample.kind))
                                .frame(width: 8, height: 8)

                            Text(sample.kind.rawValue)
                                .font(.system(size: 11.5, weight: .semibold))
                                .frame(width: 140, alignment: .leading)

                            Text(String(format: "Peak %.2f  •  Crest %.1fx", sample.peakAmplitude, sample.crestFactor))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(MacOS27Theme.labelSecondary)

                            Spacer()

                            Text(
                                String(
                                    format: "Knock %d%% / Snap %d%%",
                                    Int((sample.lowBandRatio * 100).rounded()),
                                    Int((sample.highBandRatio * 100).rounded())
                                )
                            )
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .macOS27GlassCard(cornerRadius: 10)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func calibrationMetricPill(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(MacOS27Theme.labelTertiary)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(tint.opacity(0.28), lineWidth: 0.6)
                )
        )
    }

    private func sliderRow(
        title: String,
        subtitle: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(MacOS27Theme.electricCyan)
            }
            Slider(value: value, in: range)
                .tint(MacOS27Theme.systemBlue)
        }
    }

    private func bandLabel(for index: Int) -> String {
        let labels = [
            "80", "120", "180", "260", "350", "450",
            "650", "900", "1.2k", "1.6k", "2.2k", "2.8k",
            "3.4k", "4.1k", "4.8k", "6.0k"
        ]
        return labels[index % labels.count]
    }

    private func accentColor(for gesture: AcousticGestureType) -> Color {
        switch gesture {
        case .doubleKnock:
            return MacOS27Theme.knockAmber
        case .doubleSnap:
            return MacOS27Theme.snapTeal
        case .tripleKnock:
            return MacOS27Theme.systemBlue
        case .secretRhythm:
            return MacOS27Theme.rhythmPurple
        }
    }

    private func sampleColor(for kind: ImpulseKind) -> Color {
        switch kind {
        case .chassisKnock:
            return MacOS27Theme.knockAmber
        case .fingerSnap:
            return MacOS27Theme.snapTeal
        case .typingSuppressed:
            return MacOS27Theme.systemIndigo
        case .ambientRejected:
            return .secondary
        }
    }
}
