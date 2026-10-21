import Foundation
import AppKit
import CoreGraphics

// MARK: - Part 7: Permission-Aware, Validated System Action & Automation Dispatcher

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
    public var onToggleMainWindow: (() -> Void)?

    private init() {}

    public func execute(
        _ action: SystemActionType,
        config: AcousticClassifierConfig = AcousticClassifierConfig()
    ) -> (summary: String, succeeded: Bool) {
        switch action {
        case .hudPreviewOnly:
            return ("HUD Confirmation Preview (No System Action)", true)

        case .playPauseMedia:
            sendMediaKey(Self.NX_KEYTYPE_PLAY)
            return ("Dispatched Now Playing Play / Pause", true)

        case .privacyShield:
            onTogglePrivacyShield?()
            return ("Visual Privacy Overlay Toggled", true)

        case .muteUnmuteAudio:
            sendMediaKey(Self.NX_KEYTYPE_MUTE)
            isAudioMuted.toggle()
            return (isAudioMuted ? "System Audio Muted" : "System Audio Unmuted", true)

        case .nextTrack:
            sendMediaKey(Self.NX_KEYTYPE_NEXT)
            return ("Skipped to Next Media Track", true)

        case .previousTrack:
            sendMediaKey(Self.NX_KEYTYPE_PREVIOUS)
            return ("Returned to Previous Media Track", true)

        case .missionControl:
            let mcURL = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            if FileManager.default.fileExists(atPath: mcURL.path) {
                NSWorkspace.shared.openApplication(at: mcURL, configuration: NSWorkspace.OpenConfiguration())
                return ("Opened Mission Control", true)
            }
            return ("Mission Control app not found", false)

        case .lockScreen:
            let saverURL = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
            if FileManager.default.fileExists(atPath: saverURL.path) {
                NSWorkspace.shared.openApplication(at: saverURL, configuration: NSWorkspace.OpenConfiguration())
                return ("Activated Screen Saver / Lock", true)
            }
            return ("ScreenSaverEngine not available", false)

        case .openSpotlight:
            let spotlightURL = URL(fileURLWithPath: "/System/Library/CoreServices/Spotlight.app")
            if FileManager.default.fileExists(atPath: spotlightURL.path) {
                NSWorkspace.shared.openApplication(at: spotlightURL, configuration: NSWorkspace.OpenConfiguration())
                return ("Opened Spotlight", true)
            }
            return ("Spotlight not found", false)

        case .openChatGPT:
            let chatAppURL = URL(fileURLWithPath: "/Applications/ChatGPT.app")
            if FileManager.default.fileExists(atPath: chatAppURL.path) {
                NSWorkspace.shared.openApplication(at: chatAppURL, configuration: NSWorkspace.OpenConfiguration())
                return ("Opened ChatGPT App", true)
            }
            if let url = URL(string: "https://chatgpt.com") {
                NSWorkspace.shared.open(url)
                return ("Opened ChatGPT", true)
            }
            return ("Could not open ChatGPT", false)

        case .launchApplication:
            let path = config.targetApplicationPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
                return ("Target application path not found: \(path)", false)
            }
            let appURL = URL(fileURLWithPath: path)
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            return ("Launched \(appURL.deletingPathExtension().lastPathComponent)", true)

        case .openURL:
            let raw = config.targetURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "https" || scheme == "http") else {
                return ("Invalid or disallowed URL scheme (only http/https permitted)", false)
            }
            let ok = NSWorkspace.shared.open(url)
            return (ok ? "Opened \(url.host ?? raw)" : "Failed to open URL", ok)

        case .runShortcut:
            let trimmed = config.customShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return ("No macOS Shortcut name configured in Gesture Studio", false)
            }
            // Validate shortcut name contains no shell metacharacters
            guard trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ";|&`$<>")) == nil else {
                return ("Blocked invalid characters in Shortcut name", false)
            }
            Task.detached {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                proc.arguments = ["run", trimmed]
                try? proc.run()
            }
            return ("Triggered Shortcut “\(trimmed)”", true)

        case .runAppleScript:
            let scriptSource = config.customAppleScript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !scriptSource.isEmpty else {
                return ("No AppleScript configured", false)
            }
            var errorDict: NSDictionary?
            if let script = NSAppleScript(source: scriptSource) {
                _ = script.executeAndReturnError(&errorDict)
                if let err = errorDict?[NSAppleScript.errorBriefMessage] as? String {
                    return ("AppleScript error: \(err)", false)
                }
                return ("Executed user-approved AppleScript", true)
            }
            return ("Failed to compile AppleScript", false)

        case .runShellWorkflow:
            guard config.enableShellAutomationOptIn else {
                return ("Blocked: Shell Automation is disabled in Security Settings", false)
            }
            let cmd = config.customShellCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cmd.isEmpty else {
                return ("No shell command configured", false)
            }
            Task.detached {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                proc.arguments = ["-c", cmd]
                try? proc.run()
            }
            return ("Executed opt-in shell workflow", true)

        case .toggleResonWindow:
            onToggleMainWindow?()
            return ("Toggled KnockKnock X Studio Window", true)

        case .disabled:
            return ("Gesture Disabled", false)
        }
    }

    // MARK: - Native AppKit NSSystemDefined Media Key Injection

    private func sendMediaKey(_ key: Int32) {
        func postKey(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            guard let ev = NSEvent.otherEvent(
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
            ev.cgEvent?.post(tap: .cghidEventTap)
        }
        postKey(down: true)
        postKey(down: false)
    }
}
