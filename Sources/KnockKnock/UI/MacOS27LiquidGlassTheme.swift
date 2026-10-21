import SwiftUI
import AppKit

// MARK: - Authentic macOS 27 Liquid Glass Design System

public enum MacOS27Theme {
    // Window & Popover Geometry matching macOS 27 Control Center & System Settings
    public static let controlCenterWidth: CGFloat = 356
    public static let settingsWindowWidth: CGFloat = 860
    public static let settingsWindowHeight: CGFloat = 580

    // Corner Radii matching macOS 27 Control Center & System Settings
    public static let moduleCornerRadius: CGFloat = 20
    public static let tileCornerRadius: CGFloat = 15
    public static let pillCornerRadius: CGFloat = 14
    public static let innerControlCornerRadius: CGFloat = 11
    public static let settingsIconCornerRadius: CGFloat = 7.5

    // Authentic macOS 27 System Semantic Colors
    public static let systemBlue = Color(nsColor: .systemBlue)
    public static let electricCyan = Color(nsColor: .systemCyan)
    public static let systemIndigo = Color(nsColor: .systemIndigo)
    public static let knockAmber = Color(nsColor: .systemOrange)
    public static let snapTeal = Color(nsColor: .systemTeal)
    public static let rhythmPurple = Color(nsColor: .systemPurple)
    public static let listeningGreen = Color(nsColor: .systemGreen)

    public static let labelPrimary = Color(nsColor: .labelColor)
    public static let labelSecondary = Color(nsColor: .secondaryLabelColor)
    public static let labelTertiary = Color(nsColor: .tertiaryLabelColor)

    // Specular Rim Gradients (Top-Lit Solarium Glass Specular Highlight)
    public static var specularRimGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.52), location: 0.0),
                .init(color: Color.white.opacity(0.18), location: 0.38),
                .init(color: Color.white.opacity(0.05), location: 0.75),
                .init(color: Color.white.opacity(0.22), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var activeSpecularRimGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.78), location: 0.0),
                .init(color: Color(nsColor: .systemCyan).opacity(0.45), location: 0.5),
                .init(color: Color(nsColor: .systemBlue).opacity(0.35), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - macOS 27 Liquid Glass Card Modifier

public struct MacOS27LiquidGlassCard: ViewModifier {
    public var cornerRadius: CGFloat
    public var tint: Color?
    public var isInteractive: Bool
    public var isHighlighted: Bool

    public init(
        cornerRadius: CGFloat = MacOS27Theme.moduleCornerRadius,
        tint: Color? = nil,
        isInteractive: Bool = true,
        isHighlighted: Bool = false
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.isInteractive = isInteractive
        self.isHighlighted = isHighlighted
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .glassEffect(
                tint != nil
                    ? Glass.regular.tint(tint).interactive(isInteractive)
                    : Glass.regular.interactive(isInteractive),
                in: shape
            )
            .overlay(
                shape
                    .strokeBorder(
                        isHighlighted ? MacOS27Theme.activeSpecularRimGradient : MacOS27Theme.specularRimGradient,
                        lineWidth: isHighlighted ? 1.15 : 0.75
                    )
            )
            .shadow(
                color: Color.black.opacity(isHighlighted ? 0.24 : 0.14),
                radius: isHighlighted ? 14 : 8,
                x: 0,
                y: isHighlighted ? 6 : 3
            )
    }
}

extension View {
    public func macOS27GlassCard(
        cornerRadius: CGFloat = MacOS27Theme.moduleCornerRadius,
        tint: Color? = nil,
        interactive: Bool = true,
        highlighted: Bool = false
    ) -> some View {
        modifier(
            MacOS27LiquidGlassCard(
                cornerRadius: cornerRadius,
                tint: tint,
                isInteractive: interactive,
                isHighlighted: highlighted
            )
        )
    }

    public func macOS27GlassCard(
        cornerRadius: CGFloat = MacOS27Theme.moduleCornerRadius,
        tint: Color? = nil,
        isActive: Bool,
        isInteractive: Bool = true
    ) -> some View {
        modifier(
            MacOS27LiquidGlassCard(
                cornerRadius: cornerRadius,
                tint: tint,
                isInteractive: isInteractive,
                isHighlighted: isActive
            )
        )
    }
}

// MARK: - macOS 27 System Settings Squircle Icon Badge

public struct MacOS27SettingsIconBadge: View {
    public let symbol: String
    public let topColor: Color
    public let bottomColor: Color
    public var size: CGFloat = 26

    public init(symbol: String, topColor: Color, bottomColor: Color, size: CGFloat = 26) {
        self.symbol = symbol
        self.topColor = topColor
        self.bottomColor = bottomColor
        self.size = size
    }

    public init(symbol: String, gradientColors: [Color], size: CGFloat = 26) {
        self.symbol = symbol
        self.topColor = gradientColors.first ?? MacOS27Theme.systemBlue
        self.bottomColor = gradientColors.last ?? MacOS27Theme.electricCyan
        self.size = size
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.285, style: .continuous)
        ZStack {
            shape
                .fill(
                    LinearGradient(
                        colors: [topColor, bottomColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            Image(systemName: symbol)
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: bottomColor.opacity(0.28), radius: 3, x: 0, y: 1.5)
    }
}

// MARK: - Native AppKit NSGlassEffectView Wrapper for Custom Floating Surfaces

public struct NativeAppKitGlassSurface<Content: View>: NSViewRepresentable {
    public var cornerRadius: CGFloat
    public var tintColor: NSColor?
    public var isClearStyle: Bool
    public var isInteractive: Bool
    @ViewBuilder public var content: () -> Content

    public init(
        cornerRadius: CGFloat = 22,
        tintColor: NSColor? = nil,
        isClearStyle: Bool = false,
        isInteractive: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.isClearStyle = isClearStyle
        self.isInteractive = isInteractive
        self.content = content
    }

    public init(
        cornerRadius: CGFloat = 22,
        tintColor: NSColor? = nil,
        isClearStyle: Bool = false,
        isInteractive: Bool = true
    ) where Content == EmptyView {
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.isClearStyle = isClearStyle
        self.isInteractive = isInteractive
        self.content = { EmptyView() }
    }

    public func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.style = isClearStyle ? .clear : .regular
        glassView.cornerRadius = cornerRadius
        glassView.tintColor = tintColor
        if #available(macOS 27.0, *) {
            glassView.effectIsInteractive = isInteractive
        }

        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        glassView.contentView = hostingView
        return glassView
    }

    public func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.style = isClearStyle ? .clear : .regular
        nsView.cornerRadius = cornerRadius
        nsView.tintColor = tintColor
        if #available(macOS 27.0, *) {
            nsView.effectIsInteractive = isInteractive
        }
        if let hosting = nsView.contentView as? NSHostingView<Content> {
            hosting.rootView = content()
        }
    }
}
