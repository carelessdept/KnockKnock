import Foundation
import AppKit
import CoreGraphics

// MARK: - Real macOS System Action Executor

@MainActor
public final class SystemActionExecutor {
    public static let shared = SystemActionExecutor()

    // HID System Defined Media Key Constants (IOKit / hidsystem/ev_keymap.h)
    private static let NX_KEYTYPE_SOUND_UP: Int32 = 0
    private static let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    private static let NX_KEYTYPE_MUTE: Int32 = 7
    private static let NX_KEYTYPE_PLAY: Int32 = 16
    private static let NX_KEYTYPE_NEXT: Int32 = 17
    private static let NX_KEYTYPE_PREVIOUS: Int32 = 18

    public var isAudioMuted: Bool = false
    public var onTogglePrivacyShield: (() -> Void)?

    private init() {}

    public func execute(
        _ action: SystemActionType,
        shortcutName: String = ""
    ) -> String {
        switch action {
        case .hudPreviewOnly:
            return "HUD Banner Preview (No System Action)"

        case .playPauseMedia:
            sendMediaKey(Self.NX_KEYTYPE_PLAY)
            return "Media Play / Pause Sent"

        case .privacyShield:
            onTogglePrivacyShield?()
            return "Liquid Glass Privacy Shield Toggled"

        case .muteUnmuteAudio:
            sendMediaKey(Self.NX_KEYTYPE_MUTE)
            isAudioMuted.toggle()
            return isAudioMuted ? "System Audio Muted" : "System Audio Unmuted"

        case .nextTrack:
            sendMediaKey(Self.NX_KEYTYPE_NEXT)
            return "Skipped to Next Track"

        case .previousTrack:
            sendMediaKey(Self.NX_KEYTYPE_PREVIOUS)
            return "Returned to Previous Track"

        case .missionControl:
            launchMissionControl()
            return "Mission Control Opened"

        case .lockScreen:
            startScreenSaver()
            return "Screen Saver / Lock Activated"

        case .runShortcut:
            let target = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty {
                runShortcut(named: target)
                return "Ran Shortcut “\(target)”"
            } else {
                sendMediaKey(Self.NX_KEYTYPE_PLAY)
                return "Executed Default Action"
            }

        case .disabled:
            return "Action Disabled"
        }
    }

    /// Synthesizes a native macOS HID media key event (`NSSystemDefined` subtype 8)
    /// that controls Apple Music, Spotify, YouTube in Safari/Chrome, and Now Playing.
    public func sendMediaKey(_ key: Int32) {
        func postKey(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? (0xa << 8) : (0xb << 8)))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { return }
            event.cgEvent?.post(tap: .cghidEventTap)
        }

        postKey(down: true)
        postKey(down: false)
    }

    private func launchMissionControl() {
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    private func startScreenSaver() {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    private func runShortcut(named name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        try? process.run()
    }
}
