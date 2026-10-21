import SwiftUI
import AppKit

@main
struct KnockKnockApp: App {
    @NSApplicationDelegateAdaptor(KnockKnockAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("KnockKnock Settings", id: "settings") {
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
                onTriggerAction: { gesture in
                    appDelegate.handleGestureTrigger(gesture)
                },
                onTogglePrivacyShield: {
                    appDelegate.hudController.togglePrivacyShield(engine: appDelegate.engine)
                }
            )
        } label: {
            HStack(spacing: 4) {
                Image(
                    systemName: appDelegate.engine.isListening
                        ? "waveform.circle.fill"
                        : "waveform.slash"
                )
                .symbolRenderingMode(.hierarchical)
                Text("Knock")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class KnockKnockAppDelegate: NSObject, NSApplicationDelegate {
    let engine = AcousticImpulseEngine()
    let hudController = LiquidGlassHUDController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        engine.onGestureTriggered = { [weak self] record in
            guard let self else { return }
            if record.action == .privacyShield {
                self.hudController.togglePrivacyShield(engine: self.engine)
            }
            self.hudController.showGestureHUD(for: record)
        }

        engine.startListening()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.openSettingsWindow()
            let welcomeRecord = TriggeredEventRecord(
                gesture: .doubleKnock,
                action: self.engine.gestureActions[.doubleKnock] ?? .playPauseMedia,
                confidence: 0.99,
                interPulseMs: 210,
                crestFactor: 8.6,
                isSimulated: true
            )
            self.hudController.showGestureHUD(for: welcomeRecord)
        }
    }

    func handleGestureTrigger(_ gesture: AcousticGestureType) {
        engine.simulateGesture(gesture)
    }

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.title.contains("KnockKnock") || window.identifier?.rawValue.contains("settings") == true {
            window.makeKeyAndOrderFront(nil)
            return
        }
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
