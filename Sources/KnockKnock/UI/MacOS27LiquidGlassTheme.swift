import SwiftUI
import AppKit

// MARK: - Reson Liquid Glass Design System & Brand Assets

public enum MacOS27Theme {
    // Window & Popover Dimensions
    public static let menuBarPopoverWidth: CGFloat = 330
    public static let menuBarPopoverHeight: CGFloat = 520
    public static let settingsWindowWidth: CGFloat = 940
    public static let settingsWindowHeight: CGFloat = 620
    public static let floatingHUDWidth: CGFloat = 330
    public static let floatingHUDHeight: CGFloat = 66

    // Corner Radii
    public static let windowCornerRadius: CGFloat = 22
    public static let cardCornerRadius: CGFloat = 18
    public static let innerControlCornerRadius: CGFloat = 13

    // Reson Brand Colors (Matched to Reference Image)
    public static let primaryBlue = Color(red: 0.16, green: 0.48, blue: 0.98)
    public static let electricCobalt = Color(red: 0.22, green: 0.56, blue: 1.00)
    public static let knockLowBand = Color(red: 0.20, green: 0.54, blue: 0.98)
    public static let snapHighBand = Color(red: 0.14, green: 0.78, blue: 0.96)
    public static let motionViolet = Color(red: 0.58, green: 0.42, blue: 0.98)
    public static let accentPurple = Color(red: 0.58, green: 0.42, blue: 0.98)
    public static let rhythmGold = Color(red: 0.96, green: 0.66, blue: 0.22)
    public static let statusEmerald = Color(red: 0.18, green: 0.82, blue: 0.46)
    public static let statusAmber = Color(red: 0.98, green: 0.68, blue: 0.18)
    public static let statusCoral = Color(red: 0.96, green: 0.34, blue: 0.40)

    // Luminous Frosted Glass Surfaces (Matches Reference Mockup)
    public static let windowCanvasTop = Color(red: 0.95, green: 0.96, blue: 0.99)
    public static let windowCanvasBottom = Color(red: 0.91, green: 0.93, blue: 0.97)
    public static let cardSurface = Color.white.opacity(0.78)
    public static let cardBorder = Color.white.opacity(0.92)
    public static let subtleStroke = Color(red: 0.82, green: 0.86, blue: 0.93).opacity(0.65)
    public static let primaryInk = Color(red: 0.11, green: 0.14, blue: 0.20)
    public static let secondaryInk = Color(red: 0.42, green: 0.46, blue: 0.55)
    public static let mutedInk = Color(red: 0.56, green: 0.60, blue: 0.68)

    public static var knockGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.45, blue: 0.98),
                Color(red: 0.36, green: 0.68, blue: 1.00)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    public static var snapGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.62, blue: 0.98),
                Color(red: 0.28, green: 0.84, blue: 0.98)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    public static var rhythmGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.62, blue: 0.20),
                Color(red: 1.00, green: 0.80, blue: 0.34)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    public static func springAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .linear(duration: 0.12)
            : .spring(response: 0.30, dampingFraction: 0.82)
    }

    /// Loads `ResonMark.png` from bundle resources or the known path.
    @MainActor
    public static let resonMarkNSImage: NSImage? = {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "ResonMark", withExtension: "png"),
            Bundle.main.resourceURL?.appendingPathComponent("ResonMark.png"),
            URL(fileURLWithPath: "/Applications/Reson.app/Contents/Resources/ResonMark.png"),
            URL(fileURLWithPath: "/Applications/KnockKnock.app/Contents/Resources/ResonMark.png"),
            URL(fileURLWithPath: "/Users/janardhanreddy/Downloads/KnockKnock/Sources/KnockKnock/Resources/ResonMark.png"),
            URL(fileURLWithPath: "/Users/janardhanreddy/Downloads/Glossy Reson R Logo Waves.png")
        ]
        for url in candidates.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: url.path),
               let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }()
}

// MARK: - Reson "R)))" Brand Mark View

public struct ResonBrandMark: View {
    public var size: CGFloat = 28
    public var showDarkBadge: Bool = false
    public var glowColor: Color = MacOS27Theme.primaryBlue

    public init(size: CGFloat = 28, showDarkBadge: Bool = false, glowColor: Color = MacOS27Theme.primaryBlue) {
        self.size = size
        self.showDarkBadge = showDarkBadge
        self.glowColor = glowColor
    }

    public var body: some View {
        ZStack {
            if showDarkBadge {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.15, blue: 0.22),
                                Color(red: 0.07, green: 0.09, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Circle()
                            .strokeBorder(glowColor.opacity(0.65), lineWidth: 1.2)
                    }
                    .shadow(color: glowColor.opacity(0.45), radius: 6, x: 0, y: 0)
            }

            if let nsImg = MacOS27Theme.resonMarkNSImage {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: showDarkBadge ? size * 0.76 : size, height: showDarkBadge ? size * 0.76 : size)
            } else {
                HStack(spacing: 1) {
                    Text("R")
                        .font(.system(size: size * 0.56, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, MacOS27Theme.primaryBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "wave.3.right")
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(MacOS27Theme.primaryBlue)
                }
            }
        }
    }
}

// MARK: - Reusable Luminous Frosted Glass Card

public struct LiquidGlassCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let padding: CGFloat
    let tint: Color?
    @ViewBuilder let content: () -> Content

    public init(
        cornerRadius: CGFloat = MacOS27Theme.cardCornerRadius,
        padding: CGFloat = 16,
        tint: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.tint = tint
        self.content = content
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content()
            .padding(padding)
            .background {
                ZStack {
                    shape.fill(reduceTransparency ? Color.white : MacOS27Theme.cardSurface)
                    if let tint {
                        shape.fill(
                            LinearGradient(
                                colors: [tint.opacity(0.14), tint.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                    shape.strokeBorder(MacOS27Theme.cardBorder, lineWidth: 1.2)
                    shape.strokeBorder(MacOS27Theme.subtleStroke, lineWidth: 0.6)
                }
                .shadow(color: Color.black.opacity(0.045), radius: 12, x: 0, y: 5)
            }
    }
}

public struct LiquidGlassHeroContainer<Content: View>: View {
    let isListening: Bool
    @ViewBuilder let content: () -> Content

    public init(isListening: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isListening = isListening
        self.content = content
    }

    public var body: some View {
        LiquidGlassCard(
            cornerRadius: 20,
            padding: 16,
            tint: isListening ? MacOS27Theme.primaryBlue : nil
        ) {
            content()
        }
    }
}

public struct LiquidGlassStatusPill: View {
    let title: String
    let isActive: Bool
    let accent: Color

    public init(title: String, isActive: Bool, accent: Color = MacOS27Theme.statusEmerald) {
        self.title = title
        self.isActive = isActive
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isActive ? accent : Color.gray.opacity(0.45))
                .frame(width: 8, height: 8)
                .shadow(color: isActive ? accent.opacity(0.65) : .clear, radius: 4)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(MacOS27Theme.primaryInk)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(MacOS27Theme.subtleStroke, lineWidth: 0.8)
                )
        )
    }
}
