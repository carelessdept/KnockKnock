import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Five comprehensive panes fulfilling Part 4.3 (Gesture Studio), Part 4.4 (Signal Laboratory),
/// Part 6 (Experimental Lab), Part 7 (Profiles & Automation), and Part 1.2/9 (Capability Registry & Privacy).
public enum KnockKnockSettingsPane: String, CaseIterable, Identifiable {
    case gestureStudio = "Gesture Studio"
    case rhythmAndExperimental = "Rhythm & Experimental Lab"
    case profilesAndAutomation = "Profiles & Automation"
    case signalLab = "Signal Laboratory"
    case capabilitiesAndPrivacy = "Capabilities & Privacy"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .gestureStudio:
            return "Modality, Guided Calibration & Core Mappings"
        case .rhythmAndExperimental:
            return "DTW Rhythms, Spatial Zones & Hinge Sensor"
        case .profilesAndAutomation:
            return "Per-App Contexts, Shortcuts & Workflows"
        case .signalLab:
            return "Live BMI286 200Hz, Spectral & Latency Telemetry"
        case .capabilitiesAndPrivacy:
            return "Hardware Registry, Permissions & Config Export"
        }
    }

    public var symbolName: String {
        switch self {
        case .gestureStudio:
            return "hand.tap.fill"
        case .rhythmAndExperimental:
            return "metronome.fill"
        case .profilesAndAutomation:
            return "bolt.horizontal.circle.fill"
        case .signalLab:
            return "waveform.path.ecg.rectangle.fill"
        case .capabilitiesAndPrivacy:
            return "checkmark.shield.fill"
        }
    }

    public var badgeGradient: [Color] {
        switch self {
        case .gestureStudio:
            return [MacOS27Theme.systemBlue, MacOS27Theme.electricCyan]
        case .rhythmAndExperimental:
            return [MacOS27Theme.rhythmPurple, MacOS27Theme.systemIndigo]
        case .profilesAndAutomation:
            return [MacOS27Theme.knockAmber, Color(red: 1.0, green: 0.38, blue: 0.22)]
        case .signalLab:
            return [MacOS27Theme.listeningGreen, MacOS27Theme.snapTeal]
        case .capabilitiesAndPrivacy:
            return [MacOS27Theme.systemIndigo, MacOS27Theme.systemBlue]
        }
    }
}

public struct SettingsWindowView: View {
    @Bindable var engine: AcousticImpulseEngine
    let onTriggerAction: (AcousticGestureType) -> Void
    let onTogglePrivacyShield: () -> Void

    @State private var selectedPane: KnockKnockSettingsPane = .gestureStudio
    @State private var showAdvancedDSPSettings: Bool = false
    @State private var exportImportStatusMessage: String = ""

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
                .navigationSplitViewColumnWidth(min: 235, ideal: 250, max: 275)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailHeaderBanner
                    switch selectedPane {
                    case .gestureStudio:
                        gestureStudioPane
                    case .rhythmAndExperimental:
                        rhythmAndExperimentalPane
                    case .profilesAndAutomation:
                        profilesAndAutomationPane
                    case .signalLab:
                        signalLaboratoryPane
                            .onAppear {
                                engine.registerVisibleTelemetryConsumer()
                            }
                            .onDisappear {
                                engine.unregisterVisibleTelemetryConsumer()
                            }
                    case .capabilitiesAndPrivacy:
                        capabilitiesAndPrivacyPane
                    }
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    colors: [
                        MacOS27Theme.systemBlue.opacity(0.04),
                        Color.clear,
                        MacOS27Theme.systemIndigo.opacity(0.03)
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

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                    Image(systemName: "waveform.and.magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("KnockKnock X")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.labelPrimary)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(engine.isListening ? MacOS27Theme.listeningGreen : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(engine.isListening ? "Sensing Active" : "Standby (Paused)")
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

            VStack(alignment: .leading, spacing: 7) {
                Text("DETERMINISTIC TEST TRIGGERS")
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
                        Label("2× Snap", systemImage: "waveform")
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

    // MARK: - Top Detail Banner

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
                    engine.isListening ? "Pause Sensing" : "Start Sensing",
                    systemImage: engine.isListening ? "pause.circle.fill" : "play.circle.fill"
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

    // MARK: - Pane 1: Gesture Studio & Guided Calibration (Part 4.3)

    private var gestureStudioPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Input Modality & Guided Calibration Card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Physical Sensing Modality", systemImage: "gyroscope")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    Picker("Modality", selection: Binding(
                        get: { engine.config.modalityMode },
                        set: { newMode in
                            engine.config.modalityMode = newMode
                            engine.saveConfiguration()
                            if engine.isListening {
                                engine.startListening()
                            }
                        }
                    )) {
                        ForEach(SensorModalityMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()

                    Text(engine.config.modalityMode.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Guided Hardware Calibration", systemImage: "scope")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(String(format: "Gate %.3fg", engine.config.effectiveMotionJerkGateG))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(MacOS27Theme.electricCyan)
                    }

                    Text(engine.calibrationStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Button {
                            if engine.isCalibratingKnocks {
                                engine.cancelGuidedCalibration()
                            } else {
                                engine.startGuidedKnockCalibration()
                            }
                        } label: {
                            Label(
                                engine.isCalibratingKnocks
                                    ? "Cancel Calibration (\(engine.calibrationRecordedJerks.count)/4)"
                                    : "Calibrate 4 Chassis Knocks",
                                systemImage: engine.isCalibratingKnocks ? "xmark.circle.fill" : "hand.tap.fill"
                            )
                            .font(.system(size: 11.5, weight: .semibold))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(engine.isCalibratingKnocks ? MacOS27Theme.knockAmber : MacOS27Theme.systemBlue)
                        .controlSize(.small)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .macOS27GlassCard(
                    cornerRadius: MacOS27Theme.tileCornerRadius,
                    tint: engine.isCalibratingKnocks ? MacOS27Theme.knockAmber : nil,
                    isActive: engine.isCalibratingKnocks
                )
            }

            // 2. Core Gesture Mappings
            Text("Core Physical Gestures")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            ForEach(AcousticGestureType.coreGestures) { gesture in
                gestureMappingRow(for: gesture)
            }

            // 3. Conflict Notice if Double Knock & Triple Knock are both enabled
            if (engine.gestureActions[.doubleKnock] ?? .disabled) != .disabled &&
               (engine.gestureActions[.tripleKnock] ?? .disabled) != .disabled {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                        .foregroundStyle(MacOS27Theme.electricCyan)
                    Text("Arbitration Active: Because both Double Knock and Triple Knock are enabled, KnockKnock X waits a 270 ms disambiguation window after a 2nd knock so a 3rd knock never triggers both actions.")
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }
                .padding(12)
                .macOS27GlassCard(cornerRadius: 12)
            }

            // 4. Progressive Disclosure: Advanced Recognition & Suppression Thresholds
            DisclosureGroup(isExpanded: $showAdvancedDSPSettings) {
                VStack(alignment: .leading, spacing: 14) {
                    sliderRow(
                        title: "Impact Sensitivity",
                        subtitle: "Controls how light a physical tap is detected vs. stronger deliberate knocks",
                        valueText: "\(Int((engine.config.sensitivity * 100).rounded()))%",
                        value: Binding(
                            get: { Double(engine.config.sensitivity) },
                            set: {
                                engine.config.sensitivity = Float($0)
                                engine.saveConfiguration()
                            }
                        ),
                        range: 0.15...0.95
                    )

                    Divider().opacity(0.25)

                    sliderRow(
                        title: "Minimum Classification Confidence",
                        subtitle: "Higher reliability requires cleaner cadence timing and stronger sensor agreement",
                        valueText: "\(Int((engine.config.minimumConfidence * 100).rounded()))%",
                        value: Binding(
                            get: { engine.config.minimumConfidence },
                            set: {
                                engine.config.minimumConfidence = $0
                                engine.saveConfiguration()
                            }
                        ),
                        range: 0.50...0.95
                    )

                    Divider().opacity(0.25)

                    sliderRow(
                        title: "Keyboard, Mouse & Trackpad Suppression Window",
                        subtitle: "Suppresses impacts within this window after typing, clicking, dragging, or scrolling",
                        valueText: "\(Int(engine.config.typingSuppressionWindowMs.rounded())) ms",
                        value: Binding(
                            get: { engine.config.typingSuppressionWindowMs },
                            set: {
                                engine.config.typingSuppressionWindowMs = $0
                                engine.saveConfiguration()
                            }
                        ),
                        range: 80.0...600.0
                    )

                    Divider().opacity(0.25)

                    sliderRow(
                        title: "Post-Execution Cooldown Window",
                        subtitle: "Prevents duplicate executions after a command fires",
                        valueText: "\(Int(engine.config.cooldownMs.rounded())) ms",
                        value: Binding(
                            get: { engine.config.cooldownMs },
                            set: {
                                engine.config.cooldownMs = $0
                                engine.saveConfiguration()
                            }
                        ),
                        range: 400.0...2500.0
                    )
                }
                .padding(.top, 10)
            } label: {
                Label("Advanced Recognition & False-Positive Suppression", systemImage: "tuningfork")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(14)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)
        }
    }

    private func gestureMappingRow(for gesture: AcousticGestureType) -> some View {
        let selectedAction = engine.gestureActions[gesture] ?? .disabled
        return HStack(spacing: 14) {
            MacOS27SettingsIconBadge(
                symbol: gesture.symbolName,
                gradientColors: [gesture.accentColor, MacOS27Theme.systemIndigo]
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(gesture.title)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.labelPrimary)

                    Text(gesture.frequencyBadge)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(gesture.accentColor)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(gesture.accentColor.opacity(0.15))
                        )
                }

                Text(gesture.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { engine.gestureActions[gesture] ?? .disabled },
                set: {
                    engine.gestureActions[gesture] = $0
                    engine.saveConfiguration()
                }
            )) {
                ForEach(SystemActionType.allCases) { action in
                    Label(action.title, systemImage: action.symbolName)
                        .tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 225)

            Button {
                onTriggerAction(gesture)
            } label: {
                Label("Test", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(selectedAction == .disabled)
        }
        .padding(13)
        .macOS27GlassCard(
            cornerRadius: MacOS27Theme.tileCornerRadius,
            tint: selectedAction != .disabled ? gesture.accentColor : nil,
            isActive: selectedAction != .disabled,
            isInteractive: true
        )
    }

    // MARK: - Pane 2: Rhythm Studio & Experimental Interaction Lab (Part 5.4 & Part 6)

    private var rhythmAndExperimentalPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Custom 4-Beat DTW Rhythm Studio
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom Rhythm Recorder (Normalized DTW Cadence)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("Current pattern: \(engine.rhythmPatternDescription). Works across fast and slow tempos.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                    }

                    Spacer()

                    Button {
                        engine.config.targetRhythmRatios = [1.0, 0.52, 0.52]
                        engine.rhythmPatternDescription = "4-Beat Classic (1.0× · 0.52× · 0.52×)"
                        engine.saveConfiguration()
                    } label: {
                        Label("Reset Default", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                HStack(spacing: 10) {
                    ForEach(Array(engine.config.targetRhythmRatios.enumerated()), id: \.offset) { index, ratio in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Beat \(index + 1) → \(index + 2)")
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
                        .padding(11)
                        .macOS27GlassCard(cornerRadius: 12)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        engine.recordManualRhythmBeat()
                    } label: {
                        Label(
                            engine.isRecordingRhythm
                                ? "Tap Next Beat (\(engine.recordedTapTimestamps.count) / 4)"
                                : "Record 4-Beat Rhythm by Tapping Here",
                            systemImage: engine.isRecordingRhythm ? "hand.tap.fill" : "record.circle.fill"
                        )
                        .font(.system(size: 12.5, weight: .semibold))
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
                        Label("Test Custom Rhythm", systemImage: "sparkles")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(16)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

            // 2. Experimental Interaction Lab (Part 6)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Experimental Interaction Lab (Part 6 Research Candidates)", systemImage: "flask.fill")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("OPT-IN EXPERIMENTAL")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(MacOS27Theme.knockAmber)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(MacOS27Theme.knockAmber.opacity(0.15)))
                }

                Toggle(isOn: Binding(
                    get: { engine.config.enableExperimentalSpatialZones },
                    set: {
                        engine.config.enableExperimentalSpatialZones = $0
                        engine.saveConfiguration()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("6.1 Broad Spatial Knock Zones (Left vs. Right Palm Rest)")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("Uses Bosch BMI286 gyroscope roll torque sign to distinguish Left vs. Right palm-rest double knocks on a flat desk. Does not claim centimeter precision.")
                            .font(.system(size: 11))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                    }
                }
                .toggleStyle(.switch)

                Divider().opacity(0.25)

                Toggle(isOn: Binding(
                    get: { engine.config.enableExperimentalHingeDial },
                    set: {
                        engine.config.enableExperimentalHingeDial = $0
                        engine.saveConfiguration()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("6.3 Hinge Dial (Apple SPU ma981 Lid Angle Sensor)")
                                .font(.system(size: 12.5, weight: .semibold))
                            if engine.motionService.lidAngleDegrees > 0 {
                                Text("Live Angle: \(Int(engine.motionService.lidAngleDegrees))°")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(MacOS27Theme.electricCyan)
                            }
                        }
                        Text("Triggers only on non-destructive actions when you deliberately nudge the screen lid by 4°–8°.")
                            .font(.system(size: 11))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(16)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

            if engine.config.enableExperimentalSpatialZones || engine.config.enableExperimentalHingeDial {
                ForEach(AcousticGestureType.experimentalGestures) { expGesture in
                    gestureMappingRow(for: expGesture)
                }
            }
        }
    }

    // MARK: - Pane 3: Application Profiles & Automation (Part 7)

    private var profilesAndAutomationPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Application-Specific Gesture Profiles (Active: \(engine.activeProfileName))")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))

            ForEach(Array(engine.appProfiles.enumerated()), id: \.element.id) { index, profile in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle(isOn: Binding(
                            get: { engine.appProfiles[index].isEnabled },
                            set: {
                                engine.appProfiles[index].isEnabled = $0
                                engine.saveConfiguration()
                            }
                        )) {
                            HStack(spacing: 8) {
                                Text(profile.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(profile.bundleIdentifier)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(MacOS27Theme.labelTertiary)
                            }
                        }
                        .toggleStyle(.switch)

                        Spacer()

                        Picker("Double Knock:", selection: Binding(
                            get: { engine.appProfiles[index].mappings[.doubleKnock] ?? .playPauseMedia },
                            set: {
                                engine.appProfiles[index].mappings[.doubleKnock] = $0
                                engine.saveConfiguration()
                            }
                        )) {
                            ForEach(SystemActionType.allCases) { act in
                                Text(act.shortTitle).tag(act)
                            }
                        }
                        .frame(width: 210)
                    }
                }
                .padding(13)
                .macOS27GlassCard(cornerRadius: 12)
            }

            // Automation Targets Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Configured Automation Targets")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("macOS Shortcut Name")
                            .font(.system(size: 11, weight: .semibold))
                        TextField("e.g. Focus Mode", text: Binding(
                            get: { engine.config.customShortcutName },
                            set: {
                                engine.config.customShortcutName = $0
                                engine.saveConfiguration()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Application Path")
                            .font(.system(size: 11, weight: .semibold))
                        TextField("/System/Applications/Music.app", text: Binding(
                            get: { engine.config.targetApplicationPath },
                            set: {
                                engine.config.targetApplicationPath = $0
                                engine.saveConfiguration()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target URL (http/https validated)")
                            .font(.system(size: 11, weight: .semibold))
                        TextField("https://...", text: Binding(
                            get: { engine.config.targetURLString },
                            set: {
                                engine.config.targetURLString = $0
                                engine.saveConfiguration()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("User-Approved AppleScript")
                            .font(.system(size: 11, weight: .semibold))
                        TextField("AppleScript source", text: Binding(
                            get: { engine.config.customAppleScript },
                            set: {
                                engine.config.customAppleScript = $0
                                engine.saveConfiguration()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }

                Divider().opacity(0.25)

                Toggle(isOn: Binding(
                    get: { engine.config.enableShellAutomationOptIn },
                    set: {
                        engine.config.enableShellAutomationOptIn = $0
                        engine.saveConfiguration()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Explicit Opt-In: Allow User-Configured Shell Workflow Execution")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Disabled by default for security (Part 9). Never runs downloaded or external commands.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(MacOS27Theme.labelSecondary)
                    }
                }
                .toggleStyle(.switch)

                if engine.config.enableShellAutomationOptIn {
                    TextField("Shell command", text: Binding(
                        get: { engine.config.customShellCommand },
                        set: {
                            engine.config.customShellCommand = $0
                            engine.saveConfiguration()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
            .padding(16)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)
        }
    }

    // MARK: - Pane 4: Signal Laboratory (Part 4.4 — Auto-pauses when not visible)

    private var signalLaboratoryPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Real Hardware Sensor & Mach Performance Telemetry Strip
            HStack(spacing: 10) {
                metricTile(
                    title: "BMI286 Accel Jerk",
                    value: String(format: "%.4f g", engine.currentMotionJerkG),
                    subtitle: String(format: "Sample Rate: %.0f Hz", engine.motionService.accelSampleRateHz),
                    tint: MacOS27Theme.knockAmber
                )
                metricTile(
                    title: "BMI286 Gyro Roll",
                    value: String(format: "%+.2f °/s", engine.currentGyroRollDegPerSec),
                    subtitle: "Zone: \(engine.currentSpatialZone.rawValue)",
                    tint: MacOS27Theme.electricCyan
                )
                metricTile(
                    title: "ma981 Lid Angle",
                    value: engine.motionService.lidAngleDegrees > 0
                        ? String(format: "%.0f°", engine.motionService.lidAngleDegrees)
                        : "Standby",
                    subtitle: engine.motionService.isLidMoving ? "Hinge Moving (Suppressed)" : "Hinge Stable",
                    tint: MacOS27Theme.rhythmPurple
                )
                metricTile(
                    title: "Mach Process Telemetry",
                    value: String(format: "%.1f%% CPU · %.1f MB", engine.performanceMonitor.processCPUPercent, engine.performanceMonitor.residentMemoryMB),
                    subtitle: String(format: "DSP %.0f µs · Latency %.0f ms", engine.performanceMonitor.meanCallbackMicros, engine.performanceMonitor.lastRecognitionLatencyMs),
                    tint: MacOS27Theme.listeningGreen
                )
            }

            // 2. 16-Band Spectrum & Acoustic Feature Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Live 16-Band Spectral & Transient Envelope (Active Only While Signal Lab Visible)", systemImage: "waveform.path.ecg")
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Text(String(format: "Peak %.3f · RMS %.4f · Crest %.1fx · Centroid %.0f Hz · Flux %.2f", engine.currentPeak, engine.currentRMS, engine.currentCrestFactor, engine.currentCentroidHz, engine.currentSpectralFlux))
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(engine.spectrumBands.enumerated()), id: \.offset) { idx, level in
                        let normalized = Double(min(1.0, max(0.06, level)))
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
                            .frame(height: CGFloat(8.0 + normalized * 56.0))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 68, alignment: .bottom)
            }
            .padding(14)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

            // 3. False-Positive Suppression & Rejection Counters
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("9-Stage False-Positive Suppression Counters (Total Suppressed: \(engine.performanceMonitor.suppressedEventsCount))")
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Button("Clear Telemetry") {
                        engine.recentImpulses.removeAll()
                        engine.triggerHistory.removeAll()
                        engine.rejectionCounts.removeAll()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    ForEach([
                        RejectionReason.typingOrMouseActive,
                        .sustainedAudioRejected,
                        .insufficientMotionJerk,
                        .cooldownActive,
                        .conflictArbitrated
                    ], id: \.self) { reason in
                        let cnt = engine.rejectionCounts[reason, default: 0]
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(cnt)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(MacOS27Theme.electricCyan)
                            Text(reason.rawValue.replacingOccurrences(of: "Suppressed: ", with: "").replacingOccurrences(of: "Rejected: ", with: ""))
                                .font(.system(size: 9.5))
                                .foregroundStyle(MacOS27Theme.labelSecondary)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                    }
                }
            }
            .padding(14)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

            // 4. Candidate Impulses Log
            Text("Captured Candidate Impulses (\(engine.recentImpulses.count))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            if engine.recentImpulses.isEmpty {
                Text("No impulses captured yet. Start Sensing and tap your MacBook palm rest or click a deterministic test button in the sidebar.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .macOS27GlassCard(cornerRadius: 12)
            } else {
                ForEach(engine.recentImpulses.prefix(8)) { sample in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(sample.rejectionReason == .accepted ? MacOS27Theme.listeningGreen : MacOS27Theme.knockAmber)
                            .frame(width: 8, height: 8)

                        Text(sample.kind.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 210, alignment: .leading)

                        Text(String(format: "Jerk %.3fg · Roll %+.1f°/s · Crest %.1fx", sample.motionJerkG, sample.gyroRollDegPerSec, sample.crestFactor))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(MacOS27Theme.labelSecondary)

                        Spacer()

                        Text(sample.spatialZone.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MacOS27Theme.electricCyan)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .macOS27GlassCard(cornerRadius: 10)
                }
            }
        }
    }

    // MARK: - Pane 5: Capability Registry, Privacy & Configuration Export/Import (Part 1.2 & Part 9)

    private var capabilitiesAndPrivacyPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Machine Environment Summary
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Detected Hardware Environment: \(engine.capabilities.cpuBrandString) (\(engine.capabilities.macModelIdentifier))")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    Text("OS: \(engine.capabilities.osVersionString) · Memory: \(engine.capabilities.physicalMemoryGB) GB · Offline-First Transient Processing (Zero Network Entitlements)")
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }
                Spacer()
                Button("Re-Probe Hardware") {
                    engine.capabilities.refreshHardwareAndPermissions()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
            .padding(14)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)

            // 2. Capability Registry Table
            Text("Runtime Capability & Verification Registry (Part 1.2)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            ForEach(engine.capabilities.capabilities) { cap in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(cap.name)
                            .font(.system(size: 12.5, weight: .semibold))
                        Spacer()
                        Text(cap.verificationStage.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(MacOS27Theme.systemBlue.opacity(0.16)))
                            .foregroundStyle(MacOS27Theme.electricCyan)

                        Text(cap.status.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(cap.status == .available ? MacOS27Theme.listeningGreen : MacOS27Theme.knockAmber)
                    }
                    Text("\(cap.apiOrAccessMethod) · Permission: \(cap.requiredPermission)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                    Text("Behavior: \(cap.testedBehavior) | Fallback: \(cap.fallbackStrategy)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(MacOS27Theme.labelTertiary)
                }
                .padding(11)
                .macOS27GlassCard(cornerRadius: 11)
            }

            // 3. Privacy, Battery & Configuration Export/Import
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { engine.config.pauseOnBatteryPower },
                    set: {
                        engine.config.pauseOnBatteryPower = $0
                        engine.saveConfiguration()
                    }
                )) {
                    Text("Automatically Pause Sensing on Battery Power")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .toggleStyle(.switch)

                HStack(spacing: 10) {
                    Button {
                        exportConfigurationToFile()
                    } label: {
                        Label("Export Configuration JSON…", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.glass)

                    Button {
                        importConfigurationFromFile()
                    } label: {
                        Label("Import & Validate JSON…", systemImage: "square.and.arrow.down")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.glass)

                    Button {
                        engine.resetCalibrationAndLearnedGestures()
                    } label: {
                        Label("Reset Calibration & Learned Rhythms", systemImage: "trash")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.glass)

                    Spacer()

                    Button {
                        onTogglePrivacyShield()
                    } label: {
                        Label("Test Visual Privacy Overlay", systemImage: "eye.slash.circle.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(MacOS27Theme.rhythmPurple)
                }

                if !exportImportStatusMessage.isEmpty {
                    Text(exportImportStatusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MacOS27Theme.electricCyan)
                }
            }
            .padding(14)
            .macOS27GlassCard(cornerRadius: MacOS27Theme.tileCornerRadius)
        }
    }

    // MARK: - Helpers

    private func metricTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(MacOS27Theme.labelSecondary)
            Text(value)
                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 9.5))
                .foregroundStyle(MacOS27Theme.labelTertiary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macOS27GlassCard(cornerRadius: 12)
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

    private func exportConfigurationToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "KnockKnockX-Configuration.json"
        if panel.runModal() == .OK, let url = panel.url {
            let bundle = PersistedConfigurationBundle(
                config: engine.config,
                globalMappings: engine.gestureActions,
                appProfiles: engine.appProfiles
            )
            if let data = try? ConfigurationStore.exportJSONData(bundle) {
                try? data.write(to: url)
                exportImportStatusMessage = "Exported configuration to \(url.lastPathComponent)"
            }
        }
    }

    private func importConfigurationFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            let result = ConfigurationStore.decodeAndValidate(data: data)
            engine.config = result.bundle.config
            engine.gestureActions = result.bundle.globalMappings
            engine.appProfiles = result.bundle.appProfiles
            engine.saveConfiguration()
            exportImportStatusMessage = result.warnings.isEmpty
                ? "Imported configuration cleanly from \(url.lastPathComponent)."
                : "Imported with validation adjustments: \(result.warnings.joined(separator: " "))"
        }
    }
}
