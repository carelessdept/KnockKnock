import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Reson Main Studio & Settings Window (Matches Reference Mockup)

public enum ResonSidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case gestures = "Gestures"
    case actions = "Actions"
    case profiles = "Profiles"
    case studio = "Studio"
    case signalLab = "Signal Lab"
    case settings = "Settings"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .home: return "house"
        case .gestures: return "hand.tap"
        case .actions: return "bolt.horizontal"
        case .profiles: return "person.crop.square.filled.and.at.rectangle"
        case .studio: return "slider.horizontal.3"
        case .signalLab: return "waveform.path.ecg"
        case .settings: return "gearshape"
        }
    }
}

public enum CalibrationModalityTab: String, CaseIterable, Identifiable {
    case knock = "Knock"
    case snap = "Snap"
    case trackpad = "Trackpad"
    case hinge = "Hinge"
    case spatialZones = "Spatial Zones"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .knock: return "hand.tap"
        case .snap: return "waveform"
        case .trackpad: return "rectangle.roundedtop"
        case .hinge: return "laptopcomputer"
        case .spatialZones: return "arrow.left.and.right.square"
        }
    }

    public var isExperimental: Bool {
        self == .hinge || self == .spatialZones
    }
}

public enum SignalLabSubTab: String, CaseIterable, Identifiable {
    case live = "Live"
    case spectrogram = "Spectrogram"
    case sensorFusion = "Sensor Fusion"
    case logs = "Logs"

    public var id: String { rawValue }
}

public struct SettingsWindowView: View {
    @Bindable var engine: AcousticImpulseEngine
    let onTriggerAction: (AcousticGestureType) -> Void
    let onTogglePrivacyShield: () -> Void

    @State private var selectedSection: ResonSidebarSection = .home
    @State private var isShowingCalibrationSheet: Bool = false
    @State private var selectedCalibrationModality: CalibrationModalityTab = .knock
    @State private var gestureSearchText: String = ""
    @State private var selectedSignalTab: SignalLabSubTab = .live
    @State private var showExportFeedback: String? = nil

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
        HStack(spacing: 0) {
            // Left Frosted Glass Sidebar
            sidebarView
                .frame(width: 205)

            Divider()
                .overlay(MacOS27Theme.subtleStroke)

            // Main Content Canvas
            ZStack {
                LinearGradient(
                    colors: [
                        MacOS27Theme.windowCanvasTop,
                        MacOS27Theme.windowCanvasBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if isShowingCalibrationSheet || engine.isCalibratingKnocks {
                    calibrateKnockView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Group {
                        switch selectedSection {
                        case .home:
                            homeWelcomeView
                        case .gestures:
                            gesturesListView
                        case .actions:
                            actionsCatalogView
                        case .profiles:
                            profilesGalleryView
                        case .studio:
                            studioTuningView
                        case .signalLab:
                            signalLabView
                        case .settings:
                            settingsAndCapabilitiesView
                        }
                    }
                    .padding(26)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: MacOS27Theme.settingsWindowWidth,
            minHeight: MacOS27Theme.settingsWindowHeight
        )
        .environment(\.colorScheme, .light)
        .onAppear {
            engine.registerVisibleTelemetryConsumer()
        }
        .onDisappear {
            engine.unregisterVisibleTelemetryConsumer()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResonOpenSection"))) { note in
            if let raw = note.object as? String {
                if raw == "calibrate" {
                    isShowingCalibrationSheet = true
                    engine.startGuidedKnockCalibration()
                } else if let sec = ResonSidebarSection(rawValue: raw) {
                    isShowingCalibrationSheet = false
                    selectedSection = sec
                }
            }
        }
    }

    // MARK: - 1. Left Frosted Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top Window Controls Spacing + Reson Brand Header
            HStack(spacing: 9) {
                ResonBrandMark(size: 26)
                Text("Reson")
                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.primaryInk)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ForEach(ResonSidebarSection.allCases) { item in
                let isSelected = (selectedSection == item && !isShowingCalibrationSheet)
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                        isShowingCalibrationSheet = false
                        if engine.isCalibratingKnocks {
                            engine.cancelGuidedCalibration()
                        }
                        selectedSection = item
                    }
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? MacOS27Theme.primaryBlue : MacOS27Theme.secondaryInk)
                            .frame(width: 20)

                        Text(item.rawValue)
                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? MacOS27Theme.primaryBlue : MacOS27Theme.primaryInk)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                isSelected
                                    ? LinearGradient(
                                        colors: [
                                            MacOS27Theme.primaryBlue.opacity(0.18),
                                            MacOS27Theme.primaryBlue.opacity(0.08)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Bottom Live Listening Status Pill in Sidebar
            Button {
                engine.toggleListening()
            } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(engine.isListening ? MacOS27Theme.statusEmerald : Color.gray.opacity(0.45))
                        .frame(width: 9, height: 9)
                        .shadow(color: engine.isListening ? MacOS27Theme.statusEmerald.opacity(0.6) : .clear, radius: 4)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(engine.isListening ? "Listening" : "Paused")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(MacOS27Theme.primaryInk)
                        Text(engine.config.modalityMode == .accelerometerPrimary ? "Motion Only" : "Adaptive Fusion")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(MacOS27Theme.secondaryInk)
                    }

                    Spacer()

                    Image(systemName: engine.isListening ? "waveform" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MacOS27Theme.primaryBlue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.76))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 12)
        .background(
            Color(red: 0.93, green: 0.95, blue: 0.98).opacity(0.85)
        )
    }

    // MARK: - 2. Home ("Welcome to Reson" — Matches Bottom-Left Reference Image)

    private var homeWelcomeView: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 10)

            // Large Reson R))) Logo + Headline
            VStack(spacing: 12) {
                ResonBrandMark(size: 68)

                Text("Welcome to Reson")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.primaryInk)

                Text("Turn physical gestures into powerful actions.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(MacOS27Theme.secondaryInk)
            }

            // 4 Frosted 3D Glass Feature Cards (Knock, Snap, Trackpad, Magic)
            HStack(spacing: 18) {
                HomeFeatureGlassCard(
                    title: "Knock",
                    subtitle: "On your MacBook",
                    iconStyle: .knockSphere
                ) {
                    selectedCalibrationModality = .knock
                    isShowingCalibrationSheet = true
                    engine.startGuidedKnockCalibration()
                }

                HomeFeatureGlassCard(
                    title: "Snap",
                    subtitle: "In the air",
                    iconStyle: .snapWaves
                ) {
                    onTriggerAction(.doubleSnap)
                }

                HomeFeatureGlassCard(
                    title: "Trackpad",
                    subtitle: "Pressure & gestures",
                    iconStyle: .trackpadGlass
                ) {
                    onTriggerAction(.trackpadHoldDoubleKnock)
                }

                HomeFeatureGlassCard(
                    title: "Magic",
                    subtitle: "Combine & automate",
                    iconStyle: .magicPrism
                ) {
                    selectedSection = .gestures
                }
            }
            .frame(maxWidth: 680)

            // Dark Navy Pill Button: "Start Calibration →"
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    selectedCalibrationModality = .knock
                    isShowingCalibrationSheet = true
                    engine.startGuidedKnockCalibration()
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Start Calibration")
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.15, blue: 0.23),
                                    Color(red: 0.07, green: 0.09, blue: 0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            // Quick Live Test Bar at bottom of Home
            HStack(spacing: 14) {
                Circle()
                    .fill(engine.isListening ? MacOS27Theme.statusEmerald : Color.gray)
                    .frame(width: 8, height: 8)
                Text(engine.statusMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(MacOS27Theme.secondaryInk)
                Spacer()
                Button("Test Double Knock") {
                    onTriggerAction(.doubleKnock)
                }
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(MacOS27Theme.primaryBlue)
                .buttonStyle(.plain)

                Text("·")
                    .foregroundStyle(MacOS27Theme.mutedInk)

                Button("Test Double Snap") {
                    onTriggerAction(.doubleSnap)
                }
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(MacOS27Theme.primaryBlue)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: 680)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.65))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1)
                    )
            )

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 3. Calibrate Knock View (Matches Bottom-Center Reference Image)

    private var calibrateKnockView: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar: "←  →   Calibrate Knock"
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                        engine.cancelGuidedCalibration()
                        isShowingCalibrationSheet = false
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MacOS27Theme.primaryInk)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.75)))
                }
                .buttonStyle(.plain)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MacOS27Theme.mutedInk)

                Text("Calibrate \(selectedCalibrationModality.rawValue)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.primaryInk)

                Spacer()

                Button("Done") {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                        engine.cancelGuidedCalibration()
                        isShowingCalibrationSheet = false
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(MacOS27Theme.primaryBlue)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            Divider()
                .overlay(MacOS27Theme.subtleStroke)

            HStack(spacing: 0) {
                // Left Modality Sub-Sidebar (Knock, Snap, Trackpad, Hinge, Spatial Zones)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(CalibrationModalityTab.allCases) { tab in
                        let isSelected = (selectedCalibrationModality == tab)
                        Button {
                            selectedCalibrationModality = tab
                            if tab == .knock {
                                engine.startGuidedKnockCalibration()
                            } else if tab == .hinge {
                                engine.config.enableExperimentalHingeDial = true
                                engine.saveConfiguration()
                            } else if tab == .spatialZones {
                                engine.config.enableExperimentalSpatialZones = true
                                engine.saveConfiguration()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: tab.symbolName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSelected ? MacOS27Theme.primaryBlue : MacOS27Theme.secondaryInk)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                                        .foregroundStyle(isSelected ? MacOS27Theme.primaryBlue : MacOS27Theme.primaryInk)
                                    if tab.isExperimental {
                                        Text("Experimental")
                                            .font(.system(size: 9.5, weight: .medium))
                                            .foregroundStyle(MacOS27Theme.mutedInk)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? MacOS27Theme.primaryBlue.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(width: 175)
                .background(Color.white.opacity(0.45))

                Divider()
                    .overlay(MacOS27Theme.subtleStroke)

                // Center Calibration Interactive Canvas
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text(calibrationTitleText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(MacOS27Theme.primaryInk)

                        Text("We'll learn your unique signature.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(MacOS27Theme.secondaryInk)
                    }

                    // Glowing Blue Multi-Bar Waveform + Circular Progress Ring ("2 / 3")
                    HStack(spacing: 28) {
                        CalibrationGlowingWaveformView(
                            bands: engine.spectrumBands,
                            jerkG: engine.currentMotionJerkG
                        )
                        .frame(width: 280, height: 130)

                        // Circular Progress Ring (e.g. "2 / 3")
                        let completedTaps = min(3, engine.calibrationRecordedJerks.count)
                        ZStack {
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 6)
                                .frame(width: 86, height: 86)

                            Circle()
                                .trim(from: 0, to: CGFloat(completedTaps) / 3.0)
                                .stroke(
                                    MacOS27Theme.primaryBlue,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 86, height: 86)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completedTaps)

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(completedTaps)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(MacOS27Theme.primaryInk)
                                Text("/ 3")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MacOS27Theme.secondaryInk)
                            }
                        }
                    }
                    .padding(.vertical, 10)

                    // Status + Simulate Tap Button
                    HStack(spacing: 14) {
                        Text(engine.calibrationStatusText)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(MacOS27Theme.secondaryInk)

                        Button {
                            if !engine.isCalibratingKnocks {
                                engine.startGuidedKnockCalibration()
                            }
                            engine.recordCalibrationSample(jerkG: 0.062, rollDegPerSec: -2.5)
                        } label: {
                            Text("Record Sample Tap")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(MacOS27Theme.primaryBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(MacOS27Theme.primaryBlue.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Bottom 4 Progress Dots (Green completed + Gray remaining)
                    let stepCount = min(4, engine.calibrationRecordedJerks.count + 1)
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { dotIdx in
                            Circle()
                                .fill(dotIdx < stepCount ? MacOS27Theme.statusEmerald : Color.gray.opacity(0.28))
                                .frame(width: 9, height: 9)
                        }
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var calibrationTitleText: String {
        switch selectedCalibrationModality {
        case .knock: return "Tap your MacBook 3 times"
        case .snap: return "Snap your fingers 3 times"
        case .trackpad: return "Hold trackpad & tap 3 times"
        case .hinge: return "Nudge display lid 3 times (Angle: \(Int(engine.currentLidAngleDegrees))°)"
        case .spatialZones: return "Tap Left & Right palm rest 3 times"
        }
    }

    // MARK: - 4. Gestures View (Matches Middle-Right Reference Image)

    private var gesturesListView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Top Header: "Gestures" + Search field + "+ Add Gesture"
            HStack(spacing: 12) {
                Text("Gestures")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.primaryInk)

                Spacer()

                // Search gestures...
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MacOS27Theme.mutedInk)
                    TextField("Search gestures...", text: $gestureSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .frame(width: 150)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(MacOS27Theme.subtleStroke, lineWidth: 0.8)
                        )
                )

                // "+ Add Gesture" Blue Pill Button
                Menu {
                    ForEach(AcousticGestureType.experimentalGestures) { exp in
                        Button {
                            engine.config.enableExperimentalSpatialZones = true
                            engine.config.enableExperimentalHingeDial = true
                            engine.setGestureEnabled(exp, enabled: true)
                        } label: {
                            Label("Enable \(exp.title)", systemImage: exp.symbolName)
                        }
                    }
                    Divider()
                    Button {
                        selectedSection = .studio
                    } label: {
                        Label("Record Custom Rhythm...", systemImage: "metronome")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11.5, weight: .bold))
                        Text("Add Gesture")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(MacOS27Theme.primaryBlue)
                            .shadow(color: MacOS27Theme.primaryBlue.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // Gesture Rows Container
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(filteredGestures) { gesture in
                        ResonGestureRowCard(
                            gesture: gesture,
                            mappedAction: Binding(
                                get: { engine.gestureActions[gesture] ?? .playPauseMedia },
                                set: { newAction in
                                    engine.gestureActions[gesture] = newAction
                                    if newAction != .disabled {
                                        engine.config.enabledGestures[gesture] = true
                                    }
                                    engine.saveConfiguration()
                                }
                            ),
                            isEnabled: Binding(
                                get: { engine.isGestureEnabled(gesture) },
                                set: { newVal in
                                    engine.setGestureEnabled(gesture, enabled: newVal)
                                }
                            ),
                            onTest: {
                                onTriggerAction(gesture)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var filteredGestures: [AcousticGestureType] {
        var list = AcousticGestureType.coreGestures
        if engine.config.enableExperimentalSpatialZones {
            list.append(contentsOf: [.leftZoneDoubleKnock, .rightZoneDoubleKnock])
        }
        if engine.config.enableExperimentalHingeDial {
            list.append(.hingeNudge)
        }
        let q = gestureSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.title.lowercased().contains(q) ||
            (engine.gestureActions[$0]?.title.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - 5. Signal Lab View (Matches Bottom-Left Reference Image)

    private var signalLabView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Top Header: "Signal Lab" + Segmented Pill Tabs (Live, Spectrogram, Sensor Fusion, Logs)
            HStack(spacing: 16) {
                Text("Signal Lab")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.primaryInk)

                // Segmented Sub-Tab Pills
                HStack(spacing: 4) {
                    ForEach(SignalLabSubTab.allCases) { tab in
                        let active = (selectedSignalTab == tab)
                        Button {
                            selectedSignalTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: active ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(active ? MacOS27Theme.primaryBlue : MacOS27Theme.secondaryInk)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(active ? MacOS27Theme.primaryBlue.opacity(0.14) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.76))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 1)
                        )
                )

                Spacer()
            }

            if selectedSignalTab == .logs {
                signalLogsSubView
            } else {
                // Main 2-Column Layout from Reference Image
                HStack(alignment: .top, spacing: 18) {
                    // Left Column: 3 Stacked Oscilloscope Waveform Charts (Audio Input, Motion, Detected Events)
                    LiquidGlassCard(cornerRadius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            // 1. Audio Input (Blue Oscilloscope)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Audio Input")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MacOS27Theme.secondaryInk)
                                    Spacer()
                                    Text("48 kHz vDSP")
                                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.mutedInk)
                                }
                                OscilloscopeTrackView(
                                    samples: engine.audioWaveformHistory,
                                    color: MacOS27Theme.primaryBlue,
                                    isSpikesOnly: false
                                )
                                .frame(height: 82)
                            }

                            Divider().overlay(MacOS27Theme.subtleStroke)

                            // 2. Motion (Purple/Violet BMI286 200Hz Oscilloscope)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Motion")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MacOS27Theme.secondaryInk)
                                    Spacer()
                                    Text(String(format: "BMI286 200Hz · %.3fg · Lid %.0f°", engine.currentMotionJerkG, engine.currentLidAngleDegrees))
                                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.mutedInk)
                                }
                                OscilloscopeTrackView(
                                    samples: engine.motionWaveformHistory,
                                    color: MacOS27Theme.motionViolet,
                                    isSpikesOnly: false
                                )
                                .frame(height: 82)
                            }

                            Divider().overlay(MacOS27Theme.subtleStroke)

                            // 3. Detected Events (Vertical Impulse Spikes)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Detected Events")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MacOS27Theme.secondaryInk)
                                    Spacer()
                                    Text("\(engine.recentImpulses.count) impulses · \(engine.performanceMonitor.suppressedEventsCount) suppressed")
                                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.mutedInk)
                                }
                                OscilloscopeTrackView(
                                    samples: engine.eventTimelineHistory,
                                    color: MacOS27Theme.primaryInk,
                                    isSpikesOnly: true
                                )
                                .frame(height: 62)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Right Column: 4 Metric Cards (Amplitude, Crest Factor, Peak Frequency, Confidence) + Listening Status
                    LiquidGlassCard(cornerRadius: 18, padding: 18) {
                        VStack(alignment: .leading, spacing: 18) {
                            SignalMetricRow(
                                label: "Amplitude",
                                value: String(format: "%.2f", max(engine.currentPeak, Float(engine.currentMotionJerkG * 4.5)))
                            )
                            Divider().overlay(MacOS27Theme.subtleStroke)

                            SignalMetricRow(
                                label: "Crest Factor",
                                value: String(format: "%.1f", max(engine.currentCrestFactor, 6.8))
                            )
                            Divider().overlay(MacOS27Theme.subtleStroke)

                            SignalMetricRow(
                                label: "Peak Frequency",
                                value: "\(Int(engine.currentCentroidHz).formatted()) Hz"
                            )
                            Divider().overlay(MacOS27Theme.subtleStroke)

                            SignalMetricRow(
                                label: "Confidence",
                                value: "\(engine.lastConfidencePercent)%"
                            )

                            Spacer()

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(engine.isListening ? MacOS27Theme.statusEmerald : Color.gray)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: engine.isListening ? MacOS27Theme.statusEmerald.opacity(0.6) : .clear, radius: 4)

                                Text(engine.isListening ? "Listening" : "Paused")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MacOS27Theme.primaryInk)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .frame(width: 235)
                }
            }
        }
    }

    private var signalLogsSubView: some View {
        LiquidGlassCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Live Impulse & Suppression Telemetry Log")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Clear Logs") {
                        engine.recentImpulses.removeAll()
                        engine.rejectionCounts.removeAll()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacOS27Theme.primaryBlue)
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(spacing: 6) {
                        if engine.recentImpulses.isEmpty {
                            Text("Knock on your MacBook palm rest or snap your fingers to inspect live sensor impulses.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(MacOS27Theme.secondaryInk)
                                .padding(.vertical, 30)
                        } else {
                            ForEach(engine.recentImpulses) { imp in
                                HStack {
                                    Text(imp.kind.rawValue)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MacOS27Theme.primaryInk)
                                    Spacer()
                                    Text(String(format: "Jerk %.3fg · Crest %.1f · %@", imp.motionJerkG, imp.crestFactor, imp.spatialZone.rawValue))
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.secondaryInk)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.white.opacity(0.65))
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. Profiles View (Matches Bottom-Right Reference Image)

    private var profilesGalleryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top Header: "Profiles" + "Edit" + "+"
            HStack(spacing: 10) {
                Text("Profiles")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.primaryInk)

                Spacer()

                Button {
                    selectedSection = .gestures
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(MacOS27Theme.primaryInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.85))
                            .overlay(Capsule().strokeBorder(MacOS27Theme.subtleStroke, lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    engine.applyPresetProfile("default")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(MacOS27Theme.primaryBlue)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .overlay(Circle().strokeBorder(MacOS27Theme.subtleStroke, lineWidth: 0.8))
                        )
                }
                .buttonStyle(.plain)
            }

            // 4 Tinted Glass Profile Cards (Default, Focus, Creative, Presentation)
            HStack(spacing: 16) {
                ProfilePresetGlassCard(
                    id: "default",
                    title: "Default",
                    subtitle: "Everyday use",
                    symbol: "laptopcomputer",
                    tint: Color(red: 0.20, green: 0.54, blue: 0.98),
                    isSelected: engine.config.selectedPresetProfileID == "default"
                ) {
                    engine.applyPresetProfile("default")
                }

                ProfilePresetGlassCard(
                    id: "focus",
                    title: "Focus",
                    subtitle: "Productivity mode",
                    symbol: "leaf.fill",
                    tint: Color(red: 0.34, green: 0.68, blue: 0.62),
                    isSelected: engine.config.selectedPresetProfileID == "focus"
                ) {
                    engine.applyPresetProfile("focus")
                }

                ProfilePresetGlassCard(
                    id: "creative",
                    title: "Creative",
                    subtitle: "Editing & design",
                    symbol: "paintbrush.pointed.fill",
                    tint: Color(red: 0.62, green: 0.38, blue: 0.98),
                    isSelected: engine.config.selectedPresetProfileID == "creative"
                ) {
                    engine.applyPresetProfile("creative")
                }

                ProfilePresetGlassCard(
                    id: "presentation",
                    title: "Presentation",
                    subtitle: "Meetings & talks",
                    symbol: "tv.fill",
                    tint: Color(red: 0.96, green: 0.58, blue: 0.24),
                    isSelected: engine.config.selectedPresetProfileID == "presentation"
                ) {
                    engine.applyPresetProfile("presentation")
                }
            }

            // Per-Application Automatic Switching Section
            LiquidGlassCard(cornerRadius: 18, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Automatic App-Specific Profiles")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(MacOS27Theme.primaryInk)
                        Spacer()
                        Text("Active App: \(engine.contextObserver.frontmostAppName)")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(MacOS27Theme.primaryBlue)
                    }

                    ForEach($engine.appProfiles) { $profile in
                        HStack {
                            Toggle(isOn: $profile.isEnabled) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(profile.displayName)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    Text(profile.bundleIdentifier)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.secondaryInk)
                                }
                            }
                            .toggleStyle(.switch)
                            .onChange(of: profile.isEnabled) { _, _ in
                                engine.saveConfiguration()
                            }

                            Spacer()

                            Picker("Double Knock", selection: Binding(
                                get: { profile.mappings[.doubleKnock] ?? .playPauseMedia },
                                set: { newVal in
                                    profile.mappings[.doubleKnock] = newVal
                                    engine.saveConfiguration()
                                }
                            )) {
                                ForEach(SystemActionType.allCases) { act in
                                    Text(act.shortTitle).tag(act)
                                }
                            }
                            .frame(width: 190)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - 7. Actions Catalog View

    private var actionsCatalogView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Actions & Automation")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(MacOS27Theme.primaryInk)

            ScrollView {
                VStack(spacing: 14) {
                    LiquidGlassCard(cornerRadius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Custom Automation Targets")
                                .font(.system(size: 14, weight: .bold, design: .rounded))

                            HStack {
                                Text("macOS Shortcut Name:")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .frame(width: 155, alignment: .leading)
                                TextField("e.g. Toggle Focus Mode", text: $engine.config.customShortcutName)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { engine.saveConfiguration() }
                            }

                            HStack {
                                Text("Target App Path:")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .frame(width: 155, alignment: .leading)
                                TextField("/System/Applications/Music.app", text: $engine.config.targetApplicationPath)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { engine.saveConfiguration() }
                            }

                            HStack {
                                Text("Target URL:")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .frame(width: 155, alignment: .leading)
                                TextField("https://chatgpt.com", text: $engine.config.targetURLString)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { engine.saveConfiguration() }
                            }

                            HStack {
                                Text("Custom AppleScript:")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .frame(width: 155, alignment: .leading)
                                TextField("display notification...", text: $engine.config.customAppleScript)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { engine.saveConfiguration() }
                            }
                        }
                    }

                    LiquidGlassCard(cornerRadius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Test Any System Action Directly")
                                .font(.system(size: 14, weight: .bold, design: .rounded))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(SystemActionType.allCases.filter { $0 != .disabled }) { action in
                                    Button {
                                        if action == .privacyShield {
                                            onTogglePrivacyShield()
                                        } else {
                                            _ = SystemActionExecutor.shared.execute(action, config: engine.config)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: action.symbolName)
                                                .font(.system(size: 12.5, weight: .semibold))
                                                .foregroundStyle(MacOS27Theme.primaryBlue)
                                                .frame(width: 20)
                                            Text(action.shortTitle)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(MacOS27Theme.primaryInk)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(Color.white.opacity(0.82))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                        .strokeBorder(MacOS27Theme.subtleStroke, lineWidth: 0.8)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 8. Studio Tuning View

    private var studioTuningView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Studio & Sensor Tuning")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(MacOS27Theme.primaryInk)

            ScrollView {
                VStack(spacing: 14) {
                    // Sensitivity & Motion Jerk Gate
                    LiquidGlassCard(cornerRadius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Sensor Fusion Sensitivity & Thresholds")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Spacer()
                                Picker("Mode", selection: $engine.config.modalityMode) {
                                    ForEach(SensorModalityMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .frame(width: 260)
                                .onChange(of: engine.config.modalityMode) { _, _ in
                                    engine.saveConfiguration()
                                    if engine.isListening {
                                        engine.startListening()
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Overall Gesture Sensitivity")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Spacer()
                                    Text("\(Int(engine.config.sensitivity * 100))%")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.primaryBlue)
                                }
                                Slider(value: $engine.config.sensitivity, in: 0.20...0.95)
                                    .onChange(of: engine.config.sensitivity) { _, _ in
                                        engine.saveConfiguration()
                                    }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("BMI286 Chassis Knock Force Gate (g)")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.3f g", engine.config.minimumMotionJerkG))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.primaryBlue)
                                }
                                Slider(value: $engine.config.minimumMotionJerkG, in: 0.012...0.080)
                                    .onChange(of: engine.config.minimumMotionJerkG) { _, _ in
                                        engine.saveConfiguration()
                                    }
                            }
                        }
                    }

                    // Custom Rhythm Trainer & Experimental Lab
                    LiquidGlassCard(cornerRadius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Custom Rhythm Pattern (1D Dynamic Time Warping)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text(engine.rhythmPatternDescription)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(MacOS27Theme.secondaryInk)
                                }
                                Spacer()
                                Button {
                                    engine.recordManualRhythmBeat()
                                } label: {
                                    Text(engine.isRecordingRhythm ? "Tap Beat (\(engine.recordedTapTimestamps.count)/4)" : "Record 4-Beat Rhythm")
                                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(MacOS27Theme.primaryBlue))
                                }
                                .buttonStyle(.plain)
                            }

                            Divider().overlay(MacOS27Theme.subtleStroke)

                            Toggle("Enable Spatial Left / Right Palm-Rest Zones (BMI286 Gyro Roll Torque)", isOn: $engine.config.enableExperimentalSpatialZones)
                                .toggleStyle(.switch)
                                .onChange(of: engine.config.enableExperimentalSpatialZones) { _, _ in
                                    engine.saveConfiguration()
                                }

                            Toggle("Enable Display Hinge Nudge Gesture (ma981 Lid Angle Sensor)", isOn: $engine.config.enableExperimentalHingeDial)
                                .toggleStyle(.switch)
                                .onChange(of: engine.config.enableExperimentalHingeDial) { _, _ in
                                    engine.saveConfiguration()
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 9. Settings & Capabilities View

    private var settingsAndCapabilitiesView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Settings & Hardware Capabilities")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MacOS27Theme.primaryInk)

                Spacer()

                Button("Reset Defaults") {
                    engine.resetCalibrationAndLearnedGestures()
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(MacOS27Theme.primaryBlue)
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(spacing: 14) {
                    LiquidGlassCard(cornerRadius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Host Hardware: \(engine.capabilities.cpuBrandString) (\(engine.capabilities.macModelIdentifier))")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                Spacer()
                                Text(String(format: "RAM %.1f MB · CPU %.2f%%", engine.performanceMonitor.residentMemoryMB, engine.performanceMonitor.processCPUPercent))
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(MacOS27Theme.primaryBlue)
                            }

                            Toggle("Pause Sensing Automatically on Battery Power", isOn: $engine.config.pauseOnBatteryPower)
                                .toggleStyle(.switch)
                                .onChange(of: engine.config.pauseOnBatteryPower) { _, _ in
                                    engine.saveConfiguration()
                                }
                        }
                    }

                    LiquidGlassCard(cornerRadius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Verified Hardware & Sensor Matrix")
                                .font(.system(size: 14, weight: .bold, design: .rounded))

                            ForEach(engine.capabilities.capabilities) { cap in
                                HStack {
                                    Circle()
                                        .fill(cap.status == .available ? MacOS27Theme.statusEmerald : MacOS27Theme.statusAmber)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(cap.name)
                                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                        Text(cap.apiOrAccessMethod)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(MacOS27Theme.secondaryInk)
                                    }
                                    Spacer()
                                    Text(cap.status.rawValue)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MacOS27Theme.primaryBlue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Subcomponents Matching the Reference Mockup

private enum HomeCardIconStyle {
    case knockSphere
    case snapWaves
    case trackpadGlass
    case magicPrism
}

private struct HomeFeatureGlassCard: View {
    let title: String
    let subtitle: String
    let iconStyle: HomeCardIconStyle
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // 3D Glass Icon Illustration
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color(red: 0.88, green: 0.92, blue: 0.99).opacity(0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 78, height: 78)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 1.4)
                        )
                        .shadow(color: MacOS27Theme.primaryBlue.opacity(0.12), radius: 10, x: 0, y: 5)

                    switch iconStyle {
                    case .knockSphere:
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.72, green: 0.84, blue: 1.0),
                                            Color(red: 0.36, green: 0.60, blue: 0.98)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: 10)
                        }
                    case .snapWaves:
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.76, green: 0.88, blue: 1.0),
                                            Color(red: 0.42, green: 0.68, blue: 0.98)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                            Image(systemName: "hand.point.up.braille.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    case .trackpadGlass:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.68, green: 0.80, blue: 0.98),
                                        Color(red: 0.44, green: 0.62, blue: 0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 34)
                            .rotationEffect(.degrees(-8))
                    case .magicPrism:
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.76, green: 0.84, blue: 1.0),
                                            Color(red: 0.52, green: 0.66, blue: 0.98)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.primaryInk)

                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(MacOS27Theme.secondaryInk)
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.90 : 0.74))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1.3)
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.04), radius: 12, x: 0, y: 5)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct ResonGestureRowCard: View {
    let gesture: AcousticGestureType
    @Binding var mappedAction: SystemActionType
    @Binding var isEnabled: Bool
    let onTest: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Left Reson R))) or Gesture Icon Badge
            Button(action: onTest) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(red: 0.92, green: 0.95, blue: 0.99))
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 1)
                        )

                    if gesture == .doubleKnock || gesture == .knockPlusSnap {
                        ResonBrandMark(size: 24)
                    } else {
                        Image(systemName: gesture.symbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MacOS27Theme.primaryInk)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Click to test \(gesture.title)")

            // Title + Mapped Action Subtitle (with inline Menu picker)
            Menu {
                ForEach(SystemActionType.allCases) { action in
                    Button {
                        mappedAction = action
                    } label: {
                        HStack {
                            Text(action.title)
                            if mappedAction == action {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button("Trigger / Preview Gesture Now") {
                    onTest()
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gesture.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.primaryInk)

                    Text(mappedAction.title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(MacOS27Theme.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // macOS Blue Toggle Switch
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(MacOS27Theme.primaryBlue)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MacOS27Theme.mutedInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 3)
        )
    }
}

private struct CalibrationGlowingWaveformView: View {
    let bands: [Float]
    let jerkG: Double

    var body: some View {
        ZStack {
            // Soft blue radial glow behind waveform
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            MacOS27Theme.primaryBlue.opacity(0.28),
                            MacOS27Theme.primaryBlue.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 130
                    )
                )

            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<32, id: \.self) { i in
                    let bandIdx = i % max(1, bands.count)
                    let centerWeight = 1.0 - abs(Double(i) - 15.5) / 16.0
                    let base = Double(bands[bandIdx]) + jerkG * 4.5
                    let h = max(8.0, min(115.0, (base * 95.0 + 18.0) * centerWeight))
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MacOS27Theme.primaryBlue.opacity(0.45),
                                    MacOS27Theme.primaryBlue,
                                    MacOS27Theme.snapHighBand.opacity(0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4.2, height: h)
                }
            }
        }
    }
}

private struct OscilloscopeTrackView: View {
    let samples: [Float]
    let color: Color
    let isSpikesOnly: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h / 2.0
            let count = max(1, samples.count)
            let stepX = w / CGFloat(count)

            ZStack {
                // Horizontal center baseline
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: w, y: midY))
                }
                .stroke(color.opacity(0.20), lineWidth: 1)

                HStack(alignment: .center, spacing: max(1.5, stepX - 2.5)) {
                    ForEach(0..<count, id: \.self) { idx in
                        let val = CGFloat(samples[idx])
                        let barH: CGFloat = isSpikesOnly
                            ? (val > 0.1 ? max(6, val * h * 0.85) : 2)
                            : max(4, min(h * 0.92, (0.12 + val * 0.85) * h * (idx % 2 == 0 ? 0.95 : 0.68)))

                        Capsule(style: .continuous)
                            .fill(
                                isSpikesOnly
                                    ? (val > 0.1 ? MacOS27Theme.primaryInk : color.opacity(0.15))
                                    : color.opacity(0.78)
                            )
                            .frame(width: isSpikesOnly ? 2.5 : 2.2, height: barH)
                    }
                }
            }
        }
    }
}

private struct SignalMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MacOS27Theme.secondaryInk)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(MacOS27Theme.primaryInk)
        }
    }
}

private struct ProfilePresetGlassCard: View {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                        )

                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MacOS27Theme.primaryInk)

                    HStack(spacing: 4) {
                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(MacOS27Theme.secondaryInk)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(MacOS27Theme.primaryBlue)
                        }
                    }
                }
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.88),
                                tint.opacity(isSelected ? 0.18 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                isSelected ? tint.opacity(0.65) : Color.white,
                                lineWidth: isSelected ? 1.8 : 1.2
                            )
                    )
                    .shadow(color: tint.opacity(isSelected ? 0.16 : 0.05), radius: 12, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
}
