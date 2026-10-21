# CAPABILITIES — Hardware & Permission Capability Matrix

Verified empirically on **`Mac17,3` (Apple M5 MacBook Air, 16 GB RAM, macOS 27.0.1 `26A434`)**.

---

## 1. Evidence Verification Stages

Every hardware sensor and system action in KnockKnock X is tracked through a 4-stage verification pipeline (`EvidenceVerificationStage`):
- **Stage A — Static Symbol Availability:** Framework/header exists in `MacOSX27.0.sdk`.
- **Stage B — Runtime Discovery:** `IOServiceMatching` / `AVCaptureDevice` / `NSWorkspace` confirms the device or service is present on the host Mac.
- **Stage C — Entitlement & Permission Check:** Verified usable by an ad-hoc signed user-space `.app` bundle without private Apple entitlements or root (`sudo`).
- **Stage D — Empirical Runtime Verification:** Live non-zero sensor samples or action dispatches verified at runtime with measured sample rate and latency.

---

## 2. Complete Capability Matrix

| ID | Capability Name | Underlying macOS API / Device | Privilege / Permission | Empirical Status on `Mac17,3` (Apple M5) | Stage | Fallback When Unavailable |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `spu_accelerometer` | **Chassis 3-Axis Accelerometer** | `IOKit.hid` · `AppleSPUHIDDriver` (`BMI286`, Page `0xFF00`, Usage `3`) | None (User-Space IOKit) | **Available · 200.0 Hz** (`22-byte` reports, $1/65536\,g$ scale) | **Stage D** | Falls back to 48 kHz Microphone structural transient detector (`80–450 Hz`). |
| `spu_gyroscope` | **Chassis 3-Axis Gyroscope** | `IOKit.hid` · `AppleSPUHIDDriver` (`BMI286`, Page `0xFF00`, Usage `9`) | None (User-Space IOKit) | **Available · 200.0 Hz** (`22-byte` reports, $1/65536\,^\circ/\text{s}$ scale) | **Stage D** | Spatial Left/Right Palm-Rest Zone estimation disables gracefully; standard Double/Triple Knock remains active. |
| `spu_lid_angle` | **Display Lid Angle Sensor** | `IOKit.hid` · `AppleSPUHIDDevice` (`ma981`, Page `0x0020`, Usage `138`) | None (User-Space IOKit) | **Available · Event-Driven** (`3-byte` reports, $1^\circ$ resolution, $0^\circ\text{--}135^\circ$) | **Stage D** | Experimental Hinge Nudge gesture is disabled; lid movement suppression is skipped. |
| `builtin_mic` | **Built-in Microphone Array** | `AVAudioEngine` + `Accelerate/vDSP` (`48 kHz` mono PCM) | `NSMicrophoneUsageDescription` (System Prompt) | **Available · 48,000 Hz** (`1024-sample` frames, `46.8 Hz` callback rate) | **Stage D** | Switches automatically to **Accelerometer-Primary (Motion-Only) Mode** so chassis knocks still work with Mic OFF! |
| `input_suppression` | **Privacy-Safe Input Activity Guard** | `CGEventSource.secondsSinceLastEventType(.combinedSessionState)` | None (No Input Monitoring TCC needed) | **Available · 1,000 Hz** timing resolution | **Stage D** | Uses acoustic/motion cadence rules alone. |
| `trackpad_chord` | **Multimodal Trackpad / Modifier Chord** | `CGEventSource.buttonState` + `NSEvent.modifierFlags` | None | **Available · Real-Time** | **Stage D** | Uses `Fn`/`Option`/`Control` modifier hold if external mouse is used. |
| `accessibility_automation` | **System Media & Workspace Automation** | `NX_KEYTYPE_PLAY`, `NSAppleScript`, `NSWorkspace`, `Process` | Accessibility TCC (for synthetic key events) | **Available** | **Stage D** | Actions that do not require Accessibility (`HUD Preview`, `Privacy Shield`, `Launch App`, `Open URL`, `Shortcuts`, `Audio Mute`) work immediately without Accessibility permission. |
