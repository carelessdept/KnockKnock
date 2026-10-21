import SwiftUI
import AppKit

/// Reson Menu Bar Popover — Matches the top-right Menu Bar companion in the Reson design spec.
public struct ControlCenterMenuBarView: View {
    @Bindable var engine: AcousticImpulseEngine
    let onOpenSettings: () -> Void
    let onStartCalibration: () -> Void
    let onOpenStudio: () -> Void
    let onTriggerAction: (AcousticGestureType) -> Void
    let onTogglePrivacyShield: () -> Void

    @State private var showAboutPopover: Bool = false

    public init(
        engine: AcousticImpulseEngine,
        onOpenSettings: @escaping () -> Void,
        onStartCalibration: @escaping () -> Void = {},
        onOpenStudio: @escaping () -> Void = {},
        onTriggerAction: @escaping (AcousticGestureType) -> Void,
        onTogglePrivacyShield: @escaping () -> Void
    ) {
        self.engine = engine
        self.onOpenSettings = onOpenSettings
        self.onStartCalibration = onStartCalibration
        self.onOpenStudio = onOpenStudio
        self.onTriggerAction = onTriggerAction
        self.onTogglePrivacyShield = onTogglePrivacyShield
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Top Header: "Reson" + Search & Settings Icons
            HStack {
                HStack(spacing: 8) {
                    ResonBrandMark(size: 22)
                    Text("Reson")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.primaryInk)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MacOS27Theme.secondaryInk)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(MacOS27Theme.secondaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            // 2. Hero Listening & Live Blue Waveform Card
            Button {
                engine.toggleListening()
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(engine.isListening ? MacOS27Theme.statusEmerald : Color.gray.opacity(0.45))
                        .frame(width: 11, height: 11)
                        .shadow(color: engine.isListening ? MacOS27Theme.statusEmerald.opacity(0.6) : .clear, radius: 5)

                    Text(engine.isListening ? "Listening" : "Paused")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.primaryInk)

                    Spacer()

                    // Live oscillating blue waveform bars
                    MenuBarMiniWaveform(bands: engine.spectrumBands, isListening: engine.isListening)
                        .frame(width: 84, height: 24)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                )
            }
            .buttonStyle(.plain)

            // 3. Mode & Recent Action Card
            VStack(spacing: 0) {
                // Mode Row
                Menu {
                    ForEach(SensorModalityMode.allCases) { mode in
                        Button {
                            engine.config.modalityMode = mode
                            engine.saveConfiguration()
                            if engine.isListening {
                                engine.startListening()
                            }
                        } label: {
                            HStack {
                                Text(modeTitle(for: mode))
                                if engine.config.modalityMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MacOS27Theme.secondaryInk)
                            .frame(width: 18)

                        Text("Mode")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MacOS27Theme.primaryInk)

                        Spacer()

                        Text(shortModeLabel(for: engine.config.modalityMode))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(MacOS27Theme.secondaryInk)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MacOS27Theme.mutedInk)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(MacOS27Theme.subtleStroke)
                    .padding(.horizontal, 10)

                // Recent Action Row
                Button {
                    if let last = engine.lastDetectedGesture {
                        onTriggerAction(last)
                    } else {
                        onTriggerAction(.doubleKnock)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MacOS27Theme.secondaryInk)
                            .frame(width: 18)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Recent Action")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(MacOS27Theme.secondaryInk)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(MacOS27Theme.mutedInk)
                            }

                            HStack {
                                Text(recentActionSummary)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(MacOS27Theme.primaryInk)
                                    .lineLimit(1)
                                Spacer()
                                Text(recentActionTimeLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(MacOS27Theme.mutedInk)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1.1)
                    )
            )

            // 4. Quick Controls (Listening, Calibrate, Studio, Settings)
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Controls")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MacOS27Theme.secondaryInk)
                    .padding(.horizontal, 4)

                HStack(spacing: 12) {
                    QuickControlCircleButton(
                        title: "Listening",
                        symbol: "waveform.circle.fill",
                        isActive: engine.isListening
                    ) {
                        engine.toggleListening()
                    }

                    QuickControlCircleButton(
                        title: "Calibrate",
                        symbol: "scope",
                        isActive: engine.isCalibratingKnocks
                    ) {
                        onStartCalibration()
                    }

                    QuickControlCircleButton(
                        title: "Studio",
                        symbol: "slider.horizontal.3",
                        isActive: false
                    ) {
                        onOpenStudio()
                    }

                    QuickControlCircleButton(
                        title: "Settings",
                        symbol: "gearshape",
                        isActive: false
                    ) {
                        onOpenSettings()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 2)

            Divider()
                .overlay(MacOS27Theme.subtleStroke)

            // 5. Bottom Action Rows (Pause for 1 Hour, Open Main Window, About Reson, Quit Reson)
            VStack(alignment: .leading, spacing: 2) {
                MenuActionRow(icon: "clock", title: "Pause for 1 Hour") {
                    engine.pauseForOneHour()
                }

                MenuActionRow(icon: "macwindow", title: "Open Main Window") {
                    onOpenSettings()
                }

                MenuActionRow(icon: "info.circle", title: "About Reson") {
                    showAboutPopover.toggle()
                }
                .popover(isPresented: $showAboutPopover) {
                    VStack(spacing: 8) {
                        ResonBrandMark(size: 46)
                        Text("Reson")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Physical & Acoustic Interaction Layer for macOS 27")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                        Text("200 Hz BMI286 SPU Sensor Fusion · 48 kHz vDSP")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(width: 280)
                }

                MenuActionRow(icon: "power", title: "Quit Reson") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: MacOS27Theme.menuBarPopoverWidth)
        .background(
            LinearGradient(
                colors: [
                    MacOS27Theme.windowCanvasTop,
                    MacOS27Theme.windowCanvasBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .environment(\.colorScheme, .light)
        .onAppear {
            engine.registerVisibleTelemetryConsumer()
        }
        .onDisappear {
            engine.unregisterVisibleTelemetryConsumer()
        }
    }

    private var recentActionSummary: String {
        if let first = engine.triggerHistory.first {
            return "\(first.gesture.title) → \(first.action.shortTitle)"
        }
        return "Double Knock → Play / Pause"
    }

    private var recentActionTimeLabel: String {
        guard let ts = engine.lastTriggerTimestamp else { return "Ready" }
        let sec = max(1, Int(Date().timeIntervalSince(ts)))
        if sec < 60 { return "\(sec)s ago" }
        return "\(sec / 60)m ago"
    }

    private func shortModeLabel(for mode: SensorModalityMode) -> String {
        switch mode {
        case .sensorFusion: return "Adaptive"
        case .accelerometerPrimary: return "Motion Only"
        case .microphoneOnly: return "Audio Only"
        }
    }

    private func modeTitle(for mode: SensorModalityMode) -> String {
        switch mode {
        case .sensorFusion: return "Adaptive (BMI286 Motion + 48kHz Audio)"
        case .accelerometerPrimary: return "Motion Only (BMI286 200Hz, Mic Off)"
        case .microphoneOnly: return "Audio Only (48kHz Microphone)"
        }
    }
}

private struct MenuBarMiniWaveform: View {
    let bands: [Float]
    let isListening: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<14, id: \.self) { idx in
                let raw = idx < bands.count ? CGFloat(bands[idx]) : 0.12
                let height = isListening ? max(4, min(22, raw * 24)) : 4
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                MacOS27Theme.primaryBlue,
                                MacOS27Theme.snapHighBand
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3.2, height: height)
            }
        }
    }
}

private struct QuickControlCircleButton: View {
    let title: String
    let symbol: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isActive
                                ? LinearGradient(
                                    colors: [MacOS27Theme.primaryBlue, MacOS27Theme.electricCobalt],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.85), Color.white.opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 54, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isActive ? Color.clear : Color.white, lineWidth: 1.1)
                        )
                        .shadow(
                            color: isActive ? MacOS27Theme.primaryBlue.opacity(0.35) : Color.black.opacity(0.04),
                            radius: 6,
                            x: 0,
                            y: 3
                        )

                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isActive ? Color.white : MacOS27Theme.primaryInk)
                }

                Text(title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? MacOS27Theme.primaryBlue : MacOS27Theme.secondaryInk)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MenuActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(MacOS27Theme.secondaryInk)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MacOS27Theme.primaryInk)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.black.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
