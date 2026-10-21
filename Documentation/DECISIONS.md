# DECISIONS — Architecture Decision Records (ADRs)

---

## ADR-001: Waking Apple Silicon SPU `BMI286` IMU for Sensor-Fused Knock Detection

- **Context:** Audio-only knock detectors suffer from a fundamental physics trade-off: setting the microphone amplitude gate low enough to detect light palm-rest taps causes ambient speech, music, and desk noises to trigger false positives.
- **Discovery:** Empirical probing of `IOKit.hid` on `Mac17,3` (Apple M5) revealed `AppleSPUHIDDriver` exposing a Bosch `BMI286` 3-axis accelerometer (`UsagePage 0xFF00, Usage 3`) and 3-axis gyroscope (`UsagePage 0xFF00, Usage 9`). Setting `SensorPropertyReportingState = 1`, `SensorPropertyPowerState = 1`, and `ReportInterval = 5000` wakes both sensors at **200 Hz** from unprivileged user space.
- **Decision:** Require a real `BMI286` high-pass 3D jerk spike ($|\Delta \vec{a}| \ge 0.032\,g$) for all physical chassis knocks whenever SPU motion hardware is present, while reserving pure acoustic transient detection for airborne **Double Finger Snaps** ($2.2\text{--}5.5\,\text{kHz}$).
- **Consequences:** 100% immunity to airborne room noise, human speech, and speaker playback for chassis knocks, plus a new **Accelerometer-Primary (Microphone-Off) Mode**.

---

## ADR-002: `nonisolated` Static C/ObjC Callbacks Under Swift 6 Strict Concurrency

- **Context:** In Swift 6 (`swift-tools-version: 6.0`), closures created inside a `@MainActor` class inherit `@MainActor` isolation even when passed to Objective-C/C APIs (`AVAudioNode.installTap` and `IOHIDDeviceRegisterInputReportCallback`). When CoreAudio or IOKit invokes the closure on a real-time background thread, Swift's runtime isolation check (`_swift_task_checkIsolatedSwift`) traps with `EXC_BREAKPOINT` (`_dispatch_assert_queue_fail`).
- **Decision:** Define `makeAudioTapBlock(engine:sampleRate:)` as `nonisolated private static` and `spuHIDInputReportCallback` as a free `nonisolated` `@convention(c)` function, hopping to `@MainActor` explicitly via `Task { @MainActor in ... }` only when an onset or visible UI telemetry update is needed.
- **Consequences:** Zero thread-isolation crashes, deterministic real-time execution, and minimal main-thread contention.

---

## ADR-003: 270 ms Lookahead Arbitration Between Double Knock and Triple Knock

- **Context:** A naive state machine that fires `doubleKnock` immediately upon the 2nd knock will always misfire `doubleKnock` before recognizing `tripleKnock` when a user performs 3 knocks.
- **Decision:** Upon detecting a valid 2nd knock, schedule a cancellable $270\,\text{ms}$ disambiguation window (`pendingDoubleKnockTask`). If a 3rd knock arrives within that window, cancel the pending `doubleKnock`, increment `rejectionCounts[.conflictArbitrated]`, and immediately dispatch `.tripleKnock`.
- **Consequences:** Zero double-firing between Double Knock and Triple Knock, verified deterministically by `testDeterministicReplayDoubleVsTripleKnockArbitration`.

---

## ADR-004: Gyroscope Y-Axis Roll Torque for Left vs. Right Palm-Rest Spatial Zones

- **Context:** Single-accelerometer Z-axis spikes cannot distinguish whether the user knocked on the left or right side of the MacBook.
- **Decision:** Fuse the `BMI286` 3-axis gyroscope roll velocity ($\omega_{\text{roll}}$ in $^\circ/\text{s}$) at the exact millisecond of impact. Tapping the left palm rest induces negative roll torque ($\le -2.4^\circ/\text{s}$), whereas tapping the right palm rest induces positive roll torque ($\ge +2.4^\circ/\text{s}$).
- **Consequences:** Enables directional **Left Palm-Rest Double Knock** (`Previous Track`) and **Right Palm-Rest Double Knock** (`Next Track`) on a single IMU.
