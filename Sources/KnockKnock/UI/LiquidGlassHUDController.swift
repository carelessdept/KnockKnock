import SwiftUI
import AppKit

// MARK: - Floating macOS 27 Dynamic Notch HUD & Full-Screen Liquid Glass Privacy Shield

@MainActor
public final class LiquidGlassHUDController {
    public static let shared = LiquidGlassHUDController()

    private var hudPanel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var privacyShieldWindow: NSPanel?
    public var isPrivacyShieldActive: Bool = false

    private init() {}

    // MARK: - Dynamic Notch Liquid Glass HUD Pill

    public func showGestureHUD(for record: TriggeredEventRecord) {
        dismissTask?.cancel()

        let hudView = MacOS27NotchHUDPillView(record: record)
        let hostingView = NSHostingView(rootView: hudView)
        let pillSize = CGSize(width: 390, height: 66)
        hostingView.frame = CGRect(origin: .zero, size: pillSize)

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let targetX = screenFrame.midX - (pillSize.width / 2)
        let targetY = screenFrame.maxY - pillSize.height - 14

        if hudPanel == nil {
            let panel = NSPanel(
                contentRect: CGRect(x: targetX, y: targetY + 18, width: pillSize.width, height: pillSize.height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.ignoresMouseEvents = false
            hudPanel = panel
        }

        guard let panel = hudPanel else { return }
        panel.contentView = hostingView
        panel.alphaValue = 0.0
        panel.setFrame(CGRect(x: targetX, y: targetY + 14, width: pillSize.width, height: pillSize.height), display: true)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1.0)
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(
                CGRect(x: targetX, y: targetY, width: pillSize.width, height: pillSize.height),
                display: true
            )
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled, let self, let panel = self.hudPanel else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.24
                panel.animator().alphaValue = 0.0
                panel.animator().setFrame(
                    CGRect(x: targetX, y: targetY + 12, width: pillSize.width, height: pillSize.height),
                    display: true
                )
            } completionHandler: {
                Task { @MainActor in
                    panel.orderOut(nil)
                }
            }
        }
    }

    // MARK: - Full-Screen macOS 27 Liquid Glass Privacy Shield

    public func togglePrivacyShield(engine: AcousticImpulseEngine) {
        if isPrivacyShieldActive {
            dismissPrivacyShield()
        } else {
            presentPrivacyShield(engine: engine)
        }
    }

    public func presentPrivacyShield(engine: AcousticImpulseEngine) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        isPrivacyShieldActive = true

        let shieldView = MacOS27PrivacyShieldOverlayView(
            engine: engine,
            onUnlock: { [weak self] in
                self?.dismissPrivacyShield()
            }
        )

        let glassBackdrop = NSGlassEffectView(frame: screen.frame)
        glassBackdrop.style = .regular
        glassBackdrop.cornerRadius = 0
        if #available(macOS 27.0, *) {
            glassBackdrop.effectIsInteractive = true
        }

        let hosting = NSHostingView(rootView: shieldView)
        hosting.frame = screen.frame
        hosting.autoresizingMask = [.width, .height]
        glassBackdrop.contentView = hosting

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.28)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = glassBackdrop
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()
        privacyShieldWindow = panel

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1.0
        }
    }

    public func dismissPrivacyShield() {
        isPrivacyShieldActive = false
        guard let panel = privacyShieldWindow else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            panel.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                panel.orderOut(nil)
                self?.privacyShieldWindow = nil
            }
        }
    }
}

// MARK: - macOS 27 Dynamic Notch HUD Pill SwiftUI View

private struct MacOS27NotchHUDPillView: View {
    let record: TriggeredEventRecord
    @State private var pulse: Bool = false

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    record.gesture.accentColor,
                                    record.gesture.accentColor.opacity(0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: record.gesture.accentColor.opacity(0.45), radius: 8, x: 0, y: 2)

                    Image(systemName: record.gesture.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: pulse)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(record.gesture.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(record.gesture.frequencyBadge)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(record.gesture.accentColor.opacity(0.18), in: Capsule())
                            .foregroundStyle(record.gesture.accentColor)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: record.action.symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(record.action.title)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(record.interPulseMs) ms")
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text(String(format: "%.1f× CREST", record.crestFactor))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .glassEffect(
                .regular.tint(record.gesture.accentColor.opacity(0.12)).interactive(),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(MacOS27Theme.activeSpecularRimGradient, lineWidth: 1.0)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)
        }
        .padding(4)
        .onAppear {
            pulse.toggle()
        }
    }
}

// MARK: - Full-Screen macOS 27 Liquid Glass Privacy Shield View

private struct MacOS27PrivacyShieldOverlayView: View {
    var engine: AcousticImpulseEngine
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            // Subtle ambient radial glow on top of NSGlassEffectView
            RadialGradient(
                colors: [
                    Color(nsColor: .systemIndigo).opacity(0.22),
                    Color(nsColor: .systemBlue).opacity(0.10),
                    Color.black.opacity(0.35)
                ],
                center: .center,
                startRadius: 40,
                endRadius: 650
            )
            .ignoresSafeArea()

            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(nsColor: .systemIndigo), Color(nsColor: .systemBlue)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: Color(nsColor: .systemIndigo).opacity(0.5), radius: 16, x: 0, y: 6)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("Liquid Glass Privacy Shield Active")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Your desktop is optically veiled. Double-Knock your MacBook chassis or click below to resume.")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }

                    // Live Mini Acoustic Spectrum Bar inside the Lock Card
                    HStack(alignment: .center, spacing: 4) {
                        ForEach(0..<engine.spectrumBands.count, id: \.self) { idx in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(nsColor: .systemCyan), Color(nsColor: .systemIndigo)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(
                                    width: 5,
                                    height: max(6, CGFloat(engine.spectrumBands[idx]) * 34)
                                )
                        }
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                    HStack(spacing: 12) {
                        Button(action: onUnlock) {
                            Label("Unlock Workspace", systemImage: "lock.open.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color(nsColor: .systemBlue))
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                }
                .padding(32)
                .frame(width: 460)
                .macOS27GlassCard(cornerRadius: 28, tint: Color(nsColor: .systemIndigo).opacity(0.10), highlighted: true)
            }
        }
    }
}
