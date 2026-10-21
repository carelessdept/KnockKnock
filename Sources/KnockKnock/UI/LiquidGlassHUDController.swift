import SwiftUI
import AppKit

// MARK: - Reson Floating Smoked-Glass HUD Pill & Privacy Shield Overlay

@MainActor
public final class LiquidGlassHUDController {
    public static let shared = LiquidGlassHUDController()

    private var hudPanel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var privacyShieldPanel: NSPanel?
    public private(set) var isPrivacyShieldActive: Bool = false

    private init() {}

    public func showGestureHUD(for record: TriggeredEventRecord) {
        dismissTask?.cancel()

        if hudPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: MacOS27Theme.floatingHUDWidth,
                    height: MacOS27Theme.floatingHUDHeight
                ),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            hudPanel = panel
        }

        guard let panel = hudPanel else { return }
        let hudView = ResonFloatingHUDPillView(record: record)
        panel.contentView = NSHostingView(rootView: hudView)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.midX - (MacOS27Theme.floatingHUDWidth / 2)
            let y = visible.maxY - MacOS27Theme.floatingHUDHeight - 16
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2100))
            guard !Task.isCancelled, let self, let panel = self.hudPanel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                Task { @MainActor in
                    panel.orderOut(nil)
                }
            })
        }
    }

    public func togglePrivacyShield(engine: AcousticImpulseEngine) {
        if isPrivacyShieldActive {
            dismissPrivacyShield()
        } else {
            presentPrivacyShield(engine: engine)
        }
    }

    public func presentPrivacyShield(engine: AcousticImpulseEngine) {
        guard let screen = NSScreen.main else { return }
        if privacyShieldPanel == nil {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            privacyShieldPanel = panel
        }

        guard let panel = privacyShieldPanel else { return }
        panel.setFrame(screen.frame, display: true)
        panel.contentView = NSHostingView(
            rootView: PrivacyShieldOverlayView(
                onDismiss: { [weak self] in
                    self?.dismissPrivacyShield()
                }
            )
        )
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()
        isPrivacyShieldActive = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1.0
        }
    }

    public func dismissPrivacyShield() {
        guard let panel = privacyShieldPanel else { return }
        isPrivacyShieldActive = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.20
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        })
    }
}

// MARK: - Reson Smoked-Glass Neon-Rimmed HUD Pill (Matches Reference Design)

private struct ResonFloatingHUDPillView: View {
    let record: TriggeredEventRecord

    private var glowColor: Color {
        switch record.gesture {
        case .doubleKnock, .doubleSnap:
            return Color(red: 0.24, green: 0.62, blue: 1.00)
        case .tripleKnock, .secretRhythm:
            return Color(red: 0.96, green: 0.68, blue: 0.24)
        case .knockPlusSnap, .trackpadHoldDoubleKnock, .leftZoneDoubleKnock, .rightZoneDoubleKnock, .hingeNudge:
            return Color(red: 0.68, green: 0.42, blue: 1.00)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left Circular Glossy Badge with Reson R))) Logo
            ResonBrandMark(size: 42, showDarkBadge: true, glowColor: glowColor)

            // Center Headline + Action Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(record.gesture.hudHeadline)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(record.action.shortTitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Right Circular Smoked Glass Action Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    )

                Image(systemName: record.action.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(width: MacOS27Theme.floatingHUDWidth - 16, height: MacOS27Theme.floatingHUDHeight - 10)
        .background {
            ZStack {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.14, green: 0.16, blue: 0.23).opacity(0.94),
                                Color(red: 0.10, green: 0.11, blue: 0.16).opacity(0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Neon left rim glow matching the reference mockup
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                glowColor.opacity(0.95),
                                glowColor.opacity(0.35),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: glowColor.opacity(0.38), radius: 12, x: -4, y: 2)
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
        }
    }
}

private struct PrivacyShieldOverlayView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.86)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ResonBrandMark(size: 72, showDarkBadge: true, glowColor: MacOS27Theme.rhythmGold)

                Text("Reson Privacy Shield Active")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Knock again or click below to restore your workspace.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))

                Button(action: onDismiss) {
                    Text("Dismiss Privacy Shield")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(MacOS27Theme.primaryBlue)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .onTapGesture {
            onDismiss()
        }
    }
}
