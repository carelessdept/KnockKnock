import SwiftUI

/// Authentic macOS 27 Control Center Liquid Glass popover panel for KnockKnock.
/// Every card, pill, hairline rim border, tint, and typography follows the macOS 27 Liquid Glass design system.
public struct ControlCenterMenuBarView: View {
    @Bindable var engine: AcousticImpulseEngine
    let onOpenSettings: () -> Void
    let onTriggerAction: (AcousticGestureType) -> Void
    let onTogglePrivacyShield: () -> Void

    @Namespace private var glassMorphNamespace

    public init(
        engine: AcousticImpulseEngine,
        onOpenSettings: @escaping () -> Void,
        onTriggerAction: @escaping (AcousticGestureType) -> Void,
        onTogglePrivacyShield: @escaping () -> Void
    ) {
        self.engine = engine
        self.onOpenSettings = onOpenSettings
        self.onTriggerAction = onTriggerAction
        self.onTogglePrivacyShield = onTogglePrivacyShield
    }

    public var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                headerHeroModule
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
                        MacOS27Theme.electricCyan.opacity(engine.isListening ? 0.08 : 0.02),
                        Color.clear,
                        MacOS27Theme.systemIndigo.opacity(engine.isListening ? 0.06 : 0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }

    // MARK: - 1. Top Control Center Hero Pill

    private var headerHeroModule: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.32, bounce: 0.2)) {
                    engine.toggleListening()
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
                        .shadow(
                            color: engine.isListening ? MacOS27Theme.systemBlue.opacity(0.42) : .clear,
                            radius: 8,
                            y: 2
                        )

                    Image(systemName: engine.isListening ? "waveform.badge.magnifyingglass" : "mic.slash.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse.byLayer, isActive: engine.isListening)
                }
            }
            .buttonStyle(.plain)
            .help(engine.isListening ? "Pause Acoustic Impulse Engine" : "Start Acoustic Impulse Engine")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("KnockKnock")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.labelPrimary)

                    Text("macOS 27")
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
                }

                Text(engine.statusMessage)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Toggle("", isOn: Binding(
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

    // MARK: - 2. Real-Time 16-Band Spectral & Crest Strip

    private var liveSpectralStripModule: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(engine.isListening ? MacOS27Theme.listeningGreen : Color.secondary.opacity(0.45))
                    .frame(width: 6.5, height: 6.5)

                Text("CHASSIS & AIR TRANSIENT SPECTRUM")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(MacOS27Theme.labelSecondary)

                Spacer()

                if engine.isTypingSuppressed {
                    Label("Keystroke Guard", systemImage: "keyboard.badge.ellipsis")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MacOS27Theme.knockAmber)
                } else {
                    Text(String(format: "Crest %.1fx", max(1.0, Double(engine.currentCrestFactor))))
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                }
            }

            // 16-Band Liquid Glass Spectrum Visualizer
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
                        .frame(height: CGFloat(6.0 + normalized * 28.0))
                        .frame(maxWidth: .infinity)
                        .animation(.interpolatingSpring(stiffness: 260, damping: 20), value: level)
                }
            }
            .frame(height: 35, alignment: .bottom)
            .padding(.horizontal, 4)

            // Dual Sub-Band Energy Pill Meters (80-450 Hz Knock vs 2.2-4.8 kHz Snap)
            HStack(spacing: 10) {
                subBandMeter(
                    title: "Knock (80–450 Hz)",
                    value: Double(engine.lowBandLevel),
                    tint: MacOS27Theme.knockAmber
                )
                subBandMeter(
                    title: "Snap (2.2–4.8 kHz)",
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

    // MARK: - 3. 2x2 Bento Gesture Grid (macOS 27 Control Center Tiles)

    private var bentoGestureGridModule: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(AcousticGestureType.allCases) { gesture in
                bentoGestureTile(for: gesture)
            }
        }
    }

    private func bentoGestureTile(for gesture: AcousticGestureType) -> some View {
        let currentAction = engine.gestureActions[gesture] ?? .disabled
        let isEnabled = currentAction != .disabled
        let accentColor = accentColor(for: gesture)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(
                            isEnabled
                                ? accentColor.opacity(0.22)
                                : Color.secondary.opacity(0.12)
                        )
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
                    .font(.system(size: 9.0, weight: .medium, design: .monospaced))
                    .foregroundStyle(MacOS27Theme.labelTertiary)
                    .lineLimit(1)
            }

            Menu {
                ForEach(SystemActionType.allCases) { actionOption in
                    Button {
                        engine.gestureActions[gesture] = actionOption
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

    // MARK: - 4. Sensitivity & Crest Control Slider Pill

    private var sensitivityModule: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Impulse Sensitivity", systemImage: "slider.horizontal.below.waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.labelPrimary)

                Spacer()

                Text("\(Int((engine.config.sensitivity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MacOS27Theme.electricCyan)
            }

            Slider(
                value: Binding(
                    get: { Double(engine.config.sensitivity) },
                    set: { newVal in
                        engine.config.sensitivity = Float(newVal)
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

    // MARK: - 5. Latest Triggered Event / Simulation Strip

    private var recentImpulseFooterModule: some View {
        HStack(spacing: 8) {
            if let latest = engine.triggerHistory.first {
                Image(systemName: latest.action.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.electricCyan)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(MacOS27Theme.electricCyan.opacity(0.16))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(latest.gesture.title) → \(latest.action.shortTitle)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MacOS27Theme.labelPrimary)
                        .lineLimit(1)

                    Text("\(latest.interPulseMs) ms gap · Crest \(String(format: "%.1fx", latest.crestFactor))")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(MacOS27Theme.labelSecondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "hand.point.up.braille.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.labelSecondary)
                    .frame(width: 24, height: 24)

                Text("Knock twice on your MacBook palm rest or click ▶ on any tile to test.")
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

    // MARK: - 6. Bottom Control Center Action Bar

    private var controlCenterActionBar: some View {
        HStack(spacing: 8) {
            Button {
                onTogglePrivacyShield()
            } label: {
                Label("Privacy Shield", systemImage: "eye.slash.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.small)

            Button {
                onOpenSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape.fill")
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
            .help("Quit KnockKnock")
        }
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
}
