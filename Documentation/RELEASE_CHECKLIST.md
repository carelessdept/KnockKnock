# RELEASE CHECKLIST & ADVERSARIAL REVIEWS (PARTS 15 & 19)

---

## 1. Five Adversarial Engineering Reviews (Part 15)

### Review A — Architecture & Concurrency Audit
- [x] **No `@MainActor` isolation traps in C/ObjC callbacks:** Both `makeAudioTapBlock` (`AVAudioNodeTapBlock`) and `spuHIDInputReportCallback` (`IOHIDReportCallback`) are `nonisolated` static/free functions. Verified zero `_dispatch_assert_queue_fail` crashes under live 200 Hz HID + 48 kHz audio load.
- [x] **Thread-safe state handoff:** `MotionProcessorState` uses `os_unfair_lock` for sub-microsecond synchronization on the IOKit run loop.
- [x] **Lifecycle resilience:** `ContextObserver` pauses sensing cleanly on system sleep, display sleep, and screen lock, and restores sensing automatically on wake.

### Review B — Signal Processing & False-Positive Audit
- [x] **Real 200 Hz `BMI286` hardware motion fusion:** Chassis knocks require physical g-force jerk ($\ge 0.032\,g$), eliminating false triggers from human speech, music, and room noise.
- [x] **9-Stage Suppression Pipeline:** Active typing/mouse guard (`350 ms`), sustained multi-buffer envelope rejection, crest factor gate, vocal formant rejection, lid movement guard, 270 ms Triple-vs-Double Knock arbitration, and post-trigger cooldown (`1100 ms`).
- [x] **Tempo-Invariant Custom Rhythms:** 4-beat cadence matching combines normalized interval ratios with 1D Dynamic Time Warping (`dtwNormalizedDistance`).

### Review C — macOS 27 Liquid Glass UI/UX & Accessibility Audit
- [x] **Native `MacOSX27.0.sdk` Liquid Glass:** Built with `GlassEffectContainer`, `.glassEffect(.regular.interactive(), in:)`, `.glassEffectID`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)`.
- [x] **5-Pane Studio Window (`920 × 640 pt`):** `Gesture Studio`, `Rhythm & Experimental Lab`, `Profiles & Automation`, `Signal Laboratory`, and `Capabilities & Privacy`.
- [x] **Accessibility Compliance:** Adapts to `accessibilityReduceMotion`, `accessibilityReduceTransparency`, and `colorSchemeContrast` (`Increase Contrast`), with monospaced numeric telemetry readouts to prevent layout jitter.

### Review D — Performance, Energy & Memory Audit
- [x] **Demand-Driven Telemetry Rendering:** `visibleTelemetryConsumers` ensures zero background SwiftUI re-renders and zero active visual timers when the Menu Bar popover and Settings window are closed.
- [x] **Real Mach Kernel Telemetry:** `PerformanceMonitor` queries `task_info` (`MACH_TASK_BASIC_INFO` and `TASK_THREAD_TIMES_INFO`) for authentic resident memory MB and CPU %.
- [x] **Battery Saver Policy:** Optional `pauseOnBatteryPower` toggle automatically suspends sensing when unplugged.

### Review E — Security, Privacy & Persistence Audit
- [x] **Zero Audio Persistence:** Raw 1,024-sample PCM buffers are processed in-place and immediately discarded.
- [x] **Microphone-Off Operation:** Full support for **Accelerometer-Primary (`BMI286` 200 Hz) Mode** with the microphone completely off.
- [x] **Corrupted Config Recovery:** `ConfigurationStore.decodeAndValidate(data:)` and `AcousticClassifierConfig.validateAndSanitize()` recover cleanly from malformed JSON and clamp out-of-range values.

---

## 2. Final Build, Test & Packaging Verification (Part 19)

- [x] `swift build -c release` succeeds with zero errors.
- [x] `swift test` passes 10/10 unit and deterministic replay test suites.
- [x] `scripts/build-app.sh` packages `dist/KnockKnock.app` (`arm64-apple-macos26.0`, ad-hoc signed with `NSMicrophoneUsageDescription` and `NSAppleEventsUsageDescription`).
- [x] Installed to `/Applications/KnockKnock.app` and verified live on `Mac17,3` (Apple M5, macOS 27.0.1).
- [x] All 11 documentation files in `Documentation/` completed and committed to GitHub.
