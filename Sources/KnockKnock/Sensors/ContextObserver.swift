import Foundation
import AppKit
import CoreGraphics
import IOKit.ps

// MARK: - Part 5 & Part 11: Context, Power, Sleep/Wake & Privacy-Safe Input Timing Observer

@MainActor
public final class ContextObserver {
    public private(set) var frontmostBundleID: String = "com.apple.finder"
    public private(set) var frontmostAppName: String = "Finder"
    public private(set) var isOnBatteryPower: Bool = false
    public private(set) var isSystemSleepingOrLocked: Bool = false

    public var onSystemLifecycleTransition: ((_ shouldPause: Bool, _ reason: String) -> Void)?
    public var onActiveAppChanged: ((_ bundleID: String, _ appName: String) -> Void)?

    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var powerTimer: Timer?

    public init() {
        updateFrontmostApplication()
        updateBatteryPowerStatus()
        registerLifecycleObservers()
    }

    public func updateFrontmostApplication() {
        if let app = NSWorkspace.shared.frontmostApplication {
            frontmostBundleID = app.bundleIdentifier ?? "unknown"
            frontmostAppName = app.localizedName ?? "Application"
        }
    }

    public func updateBatteryPowerStatus() {
        let onBattery = Self.queryIsRunningOnBattery()
        if onBattery != isOnBatteryPower {
            isOnBatteryPower = onBattery
        }
    }

    /// Privacy-safe query of milliseconds elapsed since any keyboard, mouse, trackpad, or scroll event.
    /// Does NOT inspect or record key codes or typed text.
    nonisolated public static func millisecondsSinceLastUserInput() -> Double {
        let events: [CGEventType] = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .mouseMoved,
            .leftMouseDragged,
            .scrollWheel
        ]
        var minSec = Double.greatestFiniteMagnitude
        for ev in events {
            let s = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: ev)
            if s < minSec {
                minSec = s
            }
        }
        return minSec * 1000.0
    }

    /// Checks whether the user is currently holding the trackpad/mouse button or Option+Control chord
    /// for Multimodal Physical Gesture Combinations (Part 6.5).
    nonisolated public static func isTrackpadOrModifierHeld() -> Bool {
        let leftDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let fnOrOptionHeld = flags.contains(.maskAlternate) && flags.contains(.maskControl)
        return leftDown || fnOrOptionHeld
    }

    private func registerLifecycleObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.updateFrontmostApplication()
                    self.onActiveAppChanged?(self.frontmostBundleID, self.frontmostAppName)
                }
            }
        )

        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSystemSleepingOrLocked = true
                    self?.onSystemLifecycleTransition?(true, "System entering sleep")
                }
            }
        )

        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSystemSleepingOrLocked = false
                    self?.updateBatteryPowerStatus()
                    self?.onSystemLifecycleTransition?(false, "System woke from sleep")
                }
            }
        )

        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSystemSleepingOrLocked = true
                    self?.onSystemLifecycleTransition?(true, "Display slept / lid closed")
                }
            }
        )

        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSystemSleepingOrLocked = false
                    self?.onSystemLifecycleTransition?(false, "Display woke")
                }
            }
        )

        let distCenter = DistributedNotificationCenter.default()
        distributedObservers.append(
            distCenter.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSystemSleepingOrLocked = true
                    self?.onSystemLifecycleTransition?(true, "Screen locked")
                }
            }
        )

        distributedObservers.append(
            distCenter.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSystemSleepingOrLocked = false
                    self?.onSystemLifecycleTransition?(false, "Screen unlocked")
                }
            }
        )

        powerTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBatteryPowerStatus()
            }
        }
    }

    nonisolated private static func queryIsRunningOnBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let typeCF = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() else {
            return false
        }
        let typeStr = typeCF as String
        return typeStr == kIOPSBatteryPowerValue
    }
}
