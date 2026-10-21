# PRODUCT — KnockKnock X (Reson Architecture)

**A Physical & Acoustic Interaction Layer for macOS 27 (Tahoe)**

---

## 1. Product Vision & Thesis

MacBooks contain precision physical sensors—including the **Apple Silicon SPU (`AppleSPUHIDDevice`) Bosch `BMI286` 3-Axis Accelerometer & Gyroscope**, the **`ma981` Lid Angle Sensor**, the **48 kHz built-in microphone array**, and the **Force Touch trackpad**—that are traditionally isolated inside low-level system daemons.

**KnockKnock X (Reson)** unifies these sensors into a high-trust, low-latency physical interaction layer for macOS 27:
- **Physical Knocks on the Unibody Chassis:** Knocking twice or three times on your MacBook palm rest or display lid triggers immediate system or per-app actions—corroborated by the 200 Hz `BMI286` hardware accelerometer so ambient room noise, speech, and music **cannot** cause false triggers.
- **Airborne Finger Snaps:** Snapping twice near your Mac triggers hands-free media or workspace controls from across your desk using 48 kHz `Accelerate/vDSP` spectral transient analysis ($2.2\text{--}5.5\,\text{kHz}$).
- **Tempo-Invariant Custom Rhythms:** Tap a 4-beat cadence at any comfortable tempo to trigger custom Shortcuts, AppleScripts, or Privacy Shield overlays via 1D Dynamic Time Warping (DTW).
- **Multimodal Context Modifiers:** Hold a finger on the trackpad (or hold `Fn`/`Option`) while double-knocking to unlock a zero-false-positive secondary command layer.

---

## 2. Target User Personas

| Persona | Primary Workflow | Core Value Delivered |
| :--- | :--- | :--- |
| **Developers & Engineers** | Full-screen IDE/Terminal work with background music or calls | Pause music (`Double Knock`) or mute mic (`Trackpad-Hold + Double Knock`) without leaving the active window or hunting for media keys. |
| **Presenters & Meeting Hosts** | Screen sharing on Zoom / Teams / Meet | Instant **Liquid Glass Privacy Shield** (`Triple Knock`) or instant mic mute (`Double Knock` in Zoom profile) when someone walks up to the desk. |
| **Hands-Busy Creators** | Reading physical notes, soldering, sketching, or leaning back | Hands-free track skipping (`Double Snap`) or play/pause (`Double Knock` on chassis corner) without touching the keyboard. |
| **Hardware Enthusiasts** | Exploring Apple Silicon SPU telemetry (`BMI286` & `ma981`) | Real-time **Signal Laboratory** inspecting 200 Hz g-force jerk, gyroscope roll torque, lid angle degrees, and 16-band FFT energy. |

---

## 3. Core vs. Experimental Gesture Catalog

### Tier 1: Core Shipping Gestures (Production-Default)
1. **Double Knock (`doubleKnock`)** — Two physical taps on the MacBook palm rest or chassis within $125\text{--}480\,\text{ms}$. Requires `BMI286` accelerometer jerk ($\ge 0.032\,g$) in Sensor Fusion or Motion-Only mode.
2. **Triple Knock (`tripleKnock`)** — Three physical taps on the chassis. Arbitrated against Double Knock via a $270\,\text{ms}$ lookahead window so Double Knock never misfires during a Triple Knock.
3. **Double Finger Snap (`doubleSnap`)** — Two crisp airborne finger snaps near the Mac. Identified by high crest factor ($\ge 4.2$) and dominant $2.2\text{--}5.5\,\text{kHz}$ spectral energy.
4. **Secret Rhythm (`secretRhythm`)** — User-trained 4-beat cadence matched via normalized inter-onset ratios and 1D Dynamic Time Warping (DTW).
5. **Trackpad-Hold + Double Knock (`trackpadHoldDoubleKnock`)** — Multimodal chord: rest/press on the trackpad (or hold a modifier key) while performing a Double Knock. Near-zero false-positive probability.

### Tier 2: Experimental Lab Gestures (Opt-In)
6. **Left Palm-Rest Double Knock (`leftZoneDoubleKnock`)** — Uses the `BMI286` 3-axis gyroscope Y-axis roll impulse ($\omega_{\text{roll}} \le -2.4^\circ/\text{s}$) to detect impacts on the left palm rest.
7. **Right Palm-Rest Double Knock (`rightZoneDoubleKnock`)** — Uses positive gyroscope roll torque ($\omega_{\text{roll}} \ge +2.4^\circ/\text{s}$) to detect impacts on the right palm rest.
8. **Display Hinge Nudge (`hingeNudge`)** — Uses the Apple SPU `ma981` Lid Angle Sensor (`UsagePage 0x0020, Usage 138`) to detect deliberate $\ge 4^\circ$ micro-adjustments of the display lid.

---

## 4. Supported Actions & Context Profiles

Every gesture can be mapped globally or overridden per frontmost application (`Apple Music`, `Spotify`, `Zoom Meetings`, or any custom bundle ID):
- **HUD Preview Only (Safe Mode):** Displays the macOS 27 Dynamic Notch HUD and haptic feedback without mutating system state.
- **Media & Audio:** Play / Pause Media, Next Track, Previous Track, Mute / Unmute System Audio.
- **Workspace & Privacy:** Mission Control, Lock Screen, Liquid Glass Privacy Shield Overlay, Toggle KnockKnock X Window.
- **Automation:** Launch Application, Open URL, Run macOS Shortcut (`shortcuts run`), Run Custom AppleScript, Run Shell Command (explicit opt-in).
