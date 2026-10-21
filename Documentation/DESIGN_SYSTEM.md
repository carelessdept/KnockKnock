# DESIGN SYSTEM — macOS 27 (Tahoe) Liquid Glass

---

## 1. Design Philosophy

KnockKnock X is built natively against **`MacOSX27.0.sdk` (`arm64-apple-macos26.0`)** using SwiftUI's first-party **Liquid Glass** APIs:
- `GlassEffectContainer(spacing:)` for optical refraction grouping and shared specular highlights.
- `.glassEffect(.regular, in:)` and `.glassEffect(.regular.interactive(), in:)` for interactive pills, cards, and navigation chrome.
- `.glassEffectID(_:in:)` for fluid spatial morphing across tabs and states.
- `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` for native tactile controls.

Every surface adheres to a strict **visual restraint budget**:
- **Menu Bar Companion (`380 × 560 pt`):** Focused operational cockpit—Sensing status & modality selector, live 3-channel sensor meter (`BMI286` g-jerk, Low-Mid Knock Resonance, High-Mid Snap Crispness, `ma981` Lid Angle), active gesture quick-test grid, and 1-click Calibration/Settings triggers.
- **Settings & Studio Window (`920 × 640 pt`):** 5-pane navigation split view (`Gesture Studio`, `Rhythm & Experimental Lab`, `Profiles & Automation`, `Signal Laboratory`, `Capabilities & Privacy`).
- **Dynamic Notch HUD (`340 × 64 pt`):** Borderless floating `NSPanel` anchored below the MacBook display notch that springs open on gesture recognition and auto-dismisses after $1.85\,\text{s}$.

---

## 2. Typography & Numeric Hierarchy

All numeric readouts use `.monospacedDigit()` or `.system(..., design: .monospaced)` to prevent horizontal jitter during real-time sensor updates:

| Role | Font Specification | Usage |
| :--- | :--- | :--- |
| **Window / Hero Title** | `.system(size: 18, weight: .bold, design: .rounded)` | Studio section headers |
| **Card Header** | `.system(size: 13.5, weight: .bold, design: .rounded)` | Glass card titles |
| **Body / Control Label** | `.system(size: 12, weight: .medium)` | Settings descriptions & pickers |
| **Telemetry Readout** | `.system(size: 11, weight: .semibold, design: .monospaced)` | `BMI286` g-jerk, crest factor, latency, CPU %, RSS MB |
| **Micro Badge / Pill** | `.system(size: 9.5, weight: .bold, design: .rounded)` | Status pills (`STAGE D`, `200 HZ`, `SUPPRESSED`) |

---

## 3. Semantic Color Tokens

| Token | Color / Gradient | Semantic Meaning |
| :--- | :--- | :--- |
| `knockLowBand` | `#3394FF` (Electric Cobalt) | Structural chassis impact (`BMI286` + $80\text{--}450\,\text{Hz}$) |
| `snapHighBand` | `#1FE0BA` (Crisp Mint Cyan) | Airborne finger snap ($2.2\text{--}5.5\,\text{kHz}$) |
| `rhythmGold` | `#FFBF2E` (Amber Gold) | 4-Beat Secret Rhythm & DTW cadence match |
| `accentPurple` | `#9E61FF` (Indigo Violet) | Spatial Gyroscope Zone & Experimental Lab |
| `statusEmerald` | `#2EE57A` (System Green) | Armed / Verified Stage D / Action Succeeded |
| `statusCoral` | `#FF5766` (System Coral) | Suppressed / Rejected / Permission Needed |

---

## 4. Accessibility & System Appearance Adaptation

KnockKnock X respects all macOS Accessibility environment overrides:
1. **`accessibilityReduceMotion`:** Replaces spring animations and HUD scale transitions with crisp opacity fades (`MacOS27Theme.springAnimation(reduceMotion:)`).
2. **`accessibilityReduceTransparency`:** Automatically increases card backing opacity inside `LiquidGlassCard` and `LiquidGlassHeroContainer` when Reduce Transparency is enabled.
3. **`colorSchemeContrast` (`Increase Contrast`):** Boosts specular border stroke opacity (`0.45` vs `0.18`) for high-visibility boundaries.
4. **Full VoiceOver & Keyboard Navigation:** Every gesture card, modality picker, and calibration control exposes descriptive labels and keyboard focus rings.
