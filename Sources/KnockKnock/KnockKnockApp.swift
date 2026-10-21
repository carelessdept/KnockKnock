import SwiftUI
import AppKit

@main
struct ResonApp: App {
    @NSApplicationDelegateAdaptor(ResonAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Reson", id: "settings") {
            SettingsWindowView(
                engine: appDelegate.engine,
                onTriggerAction: { gesture in
                    appDelegate.handleGestureTrigger(gesture)
                },
                onTogglePrivacyShield: {
                    appDelegate.hudController.togglePrivacyShield(engine: appDelegate.engine)
                }
            )
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(
            width: MacOS27Theme.settingsWindowWidth,
            height: MacOS27Theme.settingsWindowHeight
        )

        MenuBarExtra {
            ControlCenterMenuBarView(
                engine: appDelegate.engine,
                onOpenSettings: {
                    appDelegate.openSettingsWindow()
                },
                onStartCalibration: {
                    appDelegate.openSettingsWindow()
                    NotificationCenter.default.post(name: Notification.Name("ResonOpenSection"), object: "calibrate")
                },
                onOpenStudio: {
                    appDelegate.openSettingsWindow()
                    NotificationCenter.default.post(name: Notification.Name("ResonOpenSection"), object: "Studio")
                },
                onTriggerAction: { gesture in
                    appDelegate.handleGestureTrigger(gesture)
                },
                onTogglePrivacyShield: {
                    appDelegate.hudController.togglePrivacyShield(engine: appDelegate.engine)
                }
            )
        } label: {
            HStack(spacing: 3) {
                Text("R")
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                Image(systemName: appDelegate.engine.isListening ? "wave.3.right" : "wave.3.right.circle")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class ResonAppDelegate: NSObject, NSApplicationDelegate {
    let engine = AcousticImpulseEngine()
    let hudController = LiquidGlassHUDController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        if let iconImg = MacOS27Theme.resonMarkNSImage {
            NSApp.applicationIconImage = iconImg
        }

        SystemActionExecutor.shared.onTogglePrivacyShield = { [weak self] in
            guard let self else { return }
            self.hudController.togglePrivacyShield(engine: self.engine)
        }
        SystemActionExecutor.shared.onToggleMainWindow = { [weak self] in
            guard let self else { return }
            self.openSettingsWindow()
        }

        engine.onGestureTriggered = { [weak self] record in
            guard let self else { return }
            if record.action == .privacyShield {
                self.hudController.togglePrivacyShield(engine: self.engine)
            }
            self.hudController.showGestureHUD(for: record)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self else { return }
            self.openSettingsWindow()
        }
    }

    func handleGestureTrigger(_ gesture: AcousticGestureType) {
        engine.simulateGesture(gesture)
    }

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.title.contains("Reson") || window.identifier?.rawValue.contains("settings") == true {
            window.makeKeyAndOrderFront(nil)
            return
        }
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
