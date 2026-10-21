# KnockKnock — Native macOS 27 Liquid Glass Acoustic & Unibody Impulse Controller

<p align="center">
  <strong>Turn your MacBook’s aluminum unibody chassis and finger snaps into a touchless remote control.</strong><br/>
  Built with native <strong>macOS 27 Liquid Glass</strong> (<code>GlassEffectContainer</code>, <code>.glassEffect</code>, <code>NSGlassEffectView</code>) and real-time <code>Accelerate/vDSP</code> spectral DSP.
</p>

---

## Why KnockKnock?

When you’re leaning back watching a movie, cooking with messy hands, reading a PDF, or someone walks up behind your desk, reaching for the keyboard or hunting for a tiny button is friction.

**KnockKnock** listens locally in memory (zero audio recording, zero network permissions) for **structural unibody impulses** (`80–450 Hz` chassis knocks) and **crisp air transients** (`2.2–4.8 kHz` finger snaps) using Apple’s `Accelerate` (`vDSP`) framework, while automatically suppressing keyboard/trackpad vibrations via `CGEventSource`.

| Gesture | Acoustic Signature | Default Action |
| :--- | :--- | :--- |
| **Double Knock** (`2× Tap`) | `80–450 Hz` Low-Mid Structural Thud + Crest Factor $\ge 4.2\times$ | **Play / Pause Media** (Apple Music, Spotify, YouTube, QuickTime) |
| **Double Snap** (`2× Snap`) | `2.2–4.8 kHz` High-Mid Crisp Transient | **Next Track** |
| **Triple Knock** (`3× Tap`) | 3-Pulse Rapid Structural Burst | **Full-Screen Liquid Glass Privacy Shield** (Instant Boss Key + Audio Mute) |
| **Secret Rhythm** (`4-Beat Cadence`) | Tempo-Invariant Normalized Interval Ratios (`1.0× · 0.52× · 0.52×`) | **Mission Control** or **Run Any macOS Shortcut** |

---

## Authentic macOS 27 Liquid Glass UI & UX

Every window, popover, card, button, and border is engineered specifically for **macOS 27 (`MacOSX27.0.sdk`)**:
- **Control Center Menu Bar Popover (`ControlCenterMenuBarView`)**:
  - Uses `GlassEffectContainer`, `.glassEffect(.regular.tint(...).interactive(), in: RoundedRectangle(..., style: .continuous))`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)`.
  - Top-lit specular hairline rim borders (`0.75 pt` default, `1.15 pt` active cyan/blue refraction rim).
  - Live 16-band `vDSP` spectral visualizer + dual sub-band energy meters (`80–450 Hz` Knock vs. `2.2–4.8 kHz` Snap).
  - 2×2 Bento Gesture Grid with inline action pickers and one-click hardware simulation triggers.
- **macOS 27 System Settings Window (`SettingsWindowView`)**:
  - `NavigationSplitView` with `.containerBackground(.ultraThinMaterial, for: .window)` and authentic macOS 27 squircle gradient sidebar badges (`MacOS27SettingsIconBadge`).
  - **Acoustic Engine & Calibration**: Live RMS, Peak, Crest Factor, and Gate telemetry + Sensitivity, Minimum Crest Factor, and Keystroke Immunity sliders.
  - **Secret Rhythm Studio**: Record your own 4-beat tempo-invariant knock pattern and test it live.
- **Dynamic Notch HUD Pill & Full-Screen Liquid Glass Privacy Shield (`LiquidGlassHUDController`)**:
  - Non-activating floating `NSPanel` banner below the MacBook notch that slides down on every recognized gesture.
  - Instant full-screen `NSGlassEffectView` refraction shield (`effectIsInteractive = true`) that blurs your entire workspace on a Triple Knock (`Esc` or click anywhere to dismiss).

---

## Build & Run (macOS 27 / Xcode 27+)

### 1. Run Unit Tests
```bash
swift test
```

### 2. Build & Package Native `KnockKnock.app` Bundle
```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/KnockKnock.app
```

---

## Architecture

```text
Sources/KnockKnock/
├── KnockKnockApp.swift                 # @main App, MenuBarExtra (.window) & Settings Window scene
├── Engine/
│   └── AcousticImpulseEngine.swift     # Real-time AVAudioEngine + Accelerate/vDSP FFT & Crest classifier
├── Models/
│   └── GestureModels.swift             # Gesture/Action models + pure testable AcousticSignalMath DSP
├── Services/
│   └── SystemActionExecutor.swift      # Native HID media keys (NX_KEYTYPE_PLAY/MUTE/NEXT), Mission Control, Shortcuts
└── UI/
    ├── MacOS27LiquidGlassTheme.swift   # macOS 27 Liquid Glass tokens, specular rim borders & NSGlassEffectView
    ├── ControlCenterMenuBarView.swift  # macOS 27 Control Center Bento popover
    ├── SettingsWindowView.swift        # macOS 27 System Settings window + Secret Rhythm Studio
    └── LiquidGlassHUDController.swift  # Dynamic Notch HUD pill & Full-Screen Privacy Shield overlay
```

## Privacy & Security
- **100% On-Device Ephemeral DSP**: Audio buffers (`1024` samples) are analyzed in real time via `vDSP` and immediately discarded. No audio is ever written to disk or transmitted over the network.
- **Keystroke & Trackpad Immunity**: Queries `CGEventSource.secondsSinceLastEventType` to automatically suppress physical keyboard typing and trackpad clicks.
