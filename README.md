<div align="center">

<img src="assets/hero-banner.svg" alt="KnockKnock X — Sensor-Fused Physical & Acoustic Interaction Layer for macOS 27" width="100%" />

# KnockKnock X (Reson Architecture)

**Turn your MacBook's physical aluminum chassis (`BMI286` 200 Hz IMU), display hinge (`ma981`), and built-in microphone (`48 kHz vDSP`) into a zero-false-positive physical interaction layer for macOS 27 (Tahoe).**

[![Platform](https://img.shields.io/badge/macOS-27.0%2B%20(Tahoe)-0A84FF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/carelessdept/KnockKnock/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-6.4%20Strict%20Concurrency-F05138?style=for-the-badge&logo=swift&logoColor=white)](Package.swift)
[![Sensors](https://img.shields.io/badge/SPU%20Sensors-BMI286%20200Hz%20%2B%2048kHz%20vDSP-2EE57A?style=for-the-badge)](Documentation/SENSOR_RESEARCH.md)
[![UI](https://img.shields.io/badge/Design-Apple%20Liquid%20Glass-33D6FF?style=for-the-badge)](Documentation/DESIGN_SYSTEM.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-30D158?style=for-the-badge)](LICENSE)

[**Download Latest `.app` Bundle (`v2.0.0`)**](https://github.com/carelessdept/KnockKnock/releases/latest) · [**Sensor Research (`BMI286` & `ma981`)**](Documentation/SENSOR_RESEARCH.md) · [**Architecture**](Documentation/ARCHITECTURE.md) · [**Capability Matrix**](Documentation/CAPABILITIES.md)

</div>

---

## Why KnockKnock X (Reson)?

Traditional audio-only knock detectors suffer from an unavoidable physics flaw: lowering the microphone threshold enough to feel natural palm-rest taps causes **human speech, music, and room noise** to trigger false actions.

**KnockKnock X solves this at the hardware level** by waking the **Apple Silicon SPU (`AppleSPUHIDDriver`) Bosch `BMI286` 3-Axis Accelerometer & Gyroscope at 200 Hz** (plus the **`ma981` Lid Angle Sensor**) directly from unprivileged user space and fusing it with a **48 kHz `Accelerate/vDSP` spectral transient engine**:

1. **100% Immune to Airborne Room Noise:** Physical chassis knocks require a real mechanical `BMI286` g-force jerk spike ($|\Delta \vec{a}| \ge 0.032\,g$). Loud talking, music playback, or clapping produces $< 0.002\,g$ on the chassis accelerometer and is deterministically rejected.
2. **Works Even With the Microphone Completely OFF:** Switch to **Accelerometer-Primary (`BMI286` 200 Hz) Mode** to extinguish the macOS microphone indicator dot while keeping Double Knock, Triple Knock, Secret Rhythm, and Trackpad-Hold + Double Knock fully active.
3. **Gyroscope Spatial Zone Discrimination:** Fuses `BMI286` Y-axis roll torque ($\omega_{\text{roll}}$ in $^\circ/\text{s}$) at the millisecond of impact to distinguish **Left Palm-Rest Knocks** ($\le -2.4^\circ/\text{s}$) from **Right Palm-Rest Knocks** ($\ge +2.4^\circ/\text{s}$).
4. **9-Stage False-Positive Suppression Pipeline:** Combines `CGEventSource` keyboard/mouse activity suppression ($350\,\text{ms}$ window without logging keys), multi-buffer sustained audio rejection, crest factor gating, `ma981` lid-movement suppression, and a **$270\,\text{ms}$ Triple-vs-Double Knock lookahead arbiter** so Triple Knock never misfires Double Knock.
5. **Authentic macOS 27 Liquid Glass UI:** Built natively against `MacOSX27.0.sdk` using SwiftUI's `GlassEffectContainer`, `.glassEffect(.regular.interactive(), in:)`, `.glassEffectID`, and demand-driven telemetry rendering ($< 0.65\%$ background CPU).

---

## Gesture & Modality Catalog

| Gesture | Physical Input | Primary Sensor Modality | Default Action |
| :--- | :--- | :--- | :--- |
| **Double Knock** | Knock twice on the aluminum palm rest or lid ($125\text{--}480\,\text{ms}$) | `BMI286` 200 Hz Accel ($\ge 0.032\,g$) + $80\text{--}450\,\text{Hz}$ Resonance | **Play / Pause Media** |
| **Triple Knock** | Knock 3 times on the MacBook chassis ($270\,\text{ms}$ arbitrated) | `BMI286` 200 Hz Accel + Cadence Arbiter | **HUD Preview Only** (Safe Default) |
| **Double Finger Snap** | Snap your fingers twice in the air near your Mac | 48 kHz `vDSP` Upper-Mid Transient ($2.2\text{--}5.5\,\text{kHz}$, Crest $\ge 4.2$) | **HUD Preview Only** |
| **Trackpad-Hold + Double Knock** | Rest/press on trackpad (or hold `Fn`/`Option`) + Double Knock | Multimodal Chord (`CGEventSource` + `BMI286`) | **Mute / Unmute System Audio** |
| **Secret Rhythm (4-Beat)** | Tap any custom 4-beat cadence at any tempo | Normalized Intervals + 1D Dynamic Time Warping (DTW) | **Configurable** (e.g. Privacy Shield) |
| **Left / Right Zone Knock** *(Lab)* | Double knock on Left vs. Right palm rest | `BMI286` Gyroscope Y-Roll Torque ($\pm 2.4^\circ/\text{s}$) | **Previous / Next Track** |
| **Display Hinge Nudge** *(Lab)* | Nudge display lid by $\ge 4^\circ$ within $450\,\text{ms}$ | Apple SPU `ma981` Lid Angle Sensor (`1°` resolution) | **Configurable** |

---

## 5-Pane macOS 27 Liquid Glass Studio (`920 × 640 pt`)

1. **Gesture Studio:** Configure global action mappings, switch between `Sensor Fusion`, `Chassis Motion Only (Mic Off)`, and `Microphone Only` modes, and run the **Guided 4-Knock Calibration Wizard**.
2. **Rhythm & Experimental Lab:** Record custom 4-beat rhythms with live 1D Dynamic Time Warping tolerance tuning, and opt into **Spatial Left/Right Palm-Rest Zones** and **Display Hinge Nudge**.
3. **Profiles & Automation:** Per-application overrides for **Apple Music**, **Spotify**, **Zoom Meetings**, or custom bundle IDs, plus custom **Shortcuts**, **AppleScripts**, **App/URL Launchers**, and opt-in **Shell Workflows**.
4. **Signal Laboratory:** Live 16-band `vDSP` spectrum analyzer, real-time `BMI286` g-force jerk, gyroscope roll torque ($^\circ/\text{s}$), `ma981` lid angle ($^\circ$), explicit **Rejection & Suppression Counters**, and a 40-event impulse inspector.
5. **Capabilities & Privacy:** Live **Stage A–D Hardware Capability Matrix**, Mach kernel `task_info` CPU/RSS/latency telemetry, and JSON profile import/export.

---

## Quick Start

### Option 1 — Run Prebuilt macOS 27 App Bundle
1. Download `KnockKnock-macOS27-arm64.zip` from [**Releases**](https://github.com/carelessdept/KnockKnock/releases/latest), unzip, and drag **`KnockKnock.app`** to `/Applications`, or build and install locally:
   ```bash
   git clone https://github.com/carelessdept/KnockKnock.git
   cd KnockKnock
   ./scripts/build-app.sh
   cp -R dist/KnockKnock.app /Applications/
   open /Applications/KnockKnock.app
   ```
2. Click **Start Sensing** in the **KnockKnock Settings** window or the `Knock` Menu Bar popover.
3. Knock firmly twice (`Tap-Tap`) on your MacBook palm rest—or switch to **Chassis Motion Only** mode to test with the microphone completely off!

### Option 2 — Run Deterministic Unit & Replay Tests
```bash
swift test
```

---

## Complete Engineering Documentation (`Documentation/`)

- [**PRODUCT.md**](Documentation/PRODUCT.md) — Product thesis, personas, core vs. experimental gesture catalog.
- [**ARCHITECTURE.md**](Documentation/ARCHITECTURE.md) — Subsystem architecture, data flow, and Swift 6 `nonisolated` real-time callback isolation.
- [**CAPABILITIES.md**](Documentation/CAPABILITIES.md) — Empirical Stage A–D Hardware & Permission Capability Matrix on `Mac17,3` (Apple M5).
- [**DESIGN_SYSTEM.md**](Documentation/DESIGN_SYSTEM.md) — macOS 27 Liquid Glass visual tokens, typography, and Accessibility adaptations.
- [**SENSOR_RESEARCH.md**](Documentation/SENSOR_RESEARCH.md) — Reverse-engineered `AppleSPUHIDDriver` (`BMI286` 200 Hz IMU & `ma981` Lid Angle Sensor) report layouts.
- [**TEST_PLAN.md**](Documentation/TEST_PLAN.md) — Unit tests, `DeterministicReplayEngine` arbitration tests, and false-positive resistance matrix.
- [**PERFORMANCE.md**](Documentation/PERFORMANCE.md) — Real Mach kernel telemetry benchmarks ($0.35\text{--}0.65\%$ idle CPU, $34\text{--}45\,\text{MB}$ RSS, $28\,\mu\text{s}$ callback).
- [**SECURITY.md**](Documentation/SECURITY.md) — Zero-persistence audio privacy model, data-flow diagram, and automation safety bounds.
- [**DECISIONS.md**](Documentation/DECISIONS.md) — Architecture Decision Records (ADRs 001–004).
- [**KNOWN_ISSUES.md**](Documentation/KNOWN_ISSUES.md) — Honest hardware, clamshell, and permission boundary conditions.
- [**RELEASE_CHECKLIST.md**](Documentation/RELEASE_CHECKLIST.md) — Five Adversarial Reviews (A–E) and Definition of Done verification.

---

## License

Released under the [MIT License](LICENSE).
