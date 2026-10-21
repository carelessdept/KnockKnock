# KNOWN ISSUES & PLATFORM BOUNDARIES

In accordance with **Part 1 (Engineering Integrity)**, this document records honest hardware, OS, and acoustic boundary conditions discovered during verification.

---

## 1. Hardware & Platform Boundaries

1. **External Display / Closed-Clamshell Mode:**
   - Physical chassis knocks (`Double Knock`, `Triple Knock`, `Left/Right Zone Knock`) require physical access to the MacBook chassis (or closed lid). When the MacBook is docked across the room in closed-clamshell mode, users should use **Double Finger Snap** (airborne acoustic transient) or enable `Acoustic-Only` mode if using an external USB/Studio Display microphone.
2. **Legacy Intel Macs (`x86_64`) & Mac Desktops (`Mac mini`, `Mac Studio`, `Mac Pro`):**
   - Desktop Macs and legacy Intel Macs do not contain the Apple Silicon `AppleSPUHIDDriver` (`BMI286` / `ma981`) inertial sensors.
   - **Graceful Degradation:** `CapabilityRegistry` detects the absence of `AppleSPUHIDDriver` at launch, marks `spu_accelerometer`, `spu_gyroscope`, and `spu_lid_angle` as `Unavailable on This Mac`, disables spatial zone and hinge-nudge gestures, and automatically falls back to the 48 kHz Microphone structural resonance classifier (`80–450 Hz`).
3. **Direct Mechanical Coupling with Desk Subwoofers:**
   - While airborne audio cannot move the `BMI286` accelerometer above $0.032\,g$, placing a high-wattage subwoofer directly on the same thin wooden surface as the MacBook at high volume can transmit mechanical vibrations into the chassis.
   - **Mitigation:** Users in high-vibration environments can run the **4-Knock Guided Calibration Wizard** or raise the `Motion Jerk Gate` slider in **Signal Laboratory** up to $0.065\,g$.

---

## 2. macOS Permission & Automation Boundaries

1. **Synthetic Media Keys & Accessibility TCC:**
   - Posting system-wide `NX_KEYTYPE_PLAY`, `NX_KEYTYPE_NEXT`, or `NX_KEYTYPE_PREVIOUS` events via `NSEvent.otherEvent(with: .systemDefined, ...).cgEvent?.post(tap: .cghidEventTap)` works for media apps, while keystroke-based Mission Control fallback requires macOS **Accessibility** permission if the `/System/Applications/Mission Control.app` bundle is moved.
2. **macOS Microphone Orange Indicator Dot:**
   - When `Sensor Fusion` or `Microphone Only` mode is active, macOS displays the standard orange microphone indicator in the menu bar / Control Center.
   - **Mitigation:** Switching to **Chassis Motion Only (`BMI286` 200 Hz)** mode in the Menu Bar popover or Gesture Studio completely shuts down `AVAudioEngine`, extinguishes the microphone indicator dot, and continues recognizing physical chassis knocks with zero microphone usage.
