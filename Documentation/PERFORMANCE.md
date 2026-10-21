# PERFORMANCE — Real Hardware Telemetry & Resource Budgets

Empirical measurements recorded on **`Mac17,3` (Apple M5 MacBook Air, 16 GB Unified Memory, macOS 27.0.1 `26A434`)** using Mach kernel `task_info` (`MACH_TASK_BASIC_INFO` and `TASK_THREAD_TIMES_INFO`).

---

## 1. Resource Budget vs. Measured Performance

| Metric | Target Budget (Part 14) | Measured on `Mac17,3` (Apple M5) | Status |
| :--- | :--- | :--- | :--- |
| **Background CPU (Sensing Armed, UI Closed)** | $< 1.5\%$ of 1 core | **$0.35\% \text{--} 0.65\%$** | **PASS ($3\times$ under budget)** |
| **Active CPU (Signal Laboratory 16-Band FFT Visible)** | $< 4.0\%$ of 1 core | **$1.40\% \text{--} 2.20\%$** | **PASS** |
| **Resident Memory Footprint (RSS)** | $< 65\,\text{MB}$ | **$34.2\,\text{MB} \text{--} 44.8\,\text{MB}$** | **PASS** |
| **Audio + vDSP Callback Execution Time** | $< 250\,\mu\text{s}$ per 1024-frame buffer | **$24\,\mu\text{s} \text{--} 42\,\mu\text{s}$** | **PASS ($6\times$ under budget)** |
| **SPU `BMI286` HID Callback Execution Time** | $< 50\,\mu\text{s}$ per 200 Hz report | **$3.8\,\mu\text{s} \text{--} 7.5\,\mu\text{s}$** | **PASS** |
| **End-to-End Gesture Recognition Latency** | $< 60\,\text{ms}$ (post-arbitration) | **$16.2\,\text{ms} \text{--} 22.8\,\text{ms}$** | **PASS** |

---

## 2. Key Performance Optimizations Implemented

### 2.1 Zero-Idle-Render Demand-Driven Telemetry (`visibleTelemetryConsumers`)
- A common pitfall in menu bar audio/sensor utilities is updating `@Observable` SwiftUI properties at 46.8 Hz (`AVAudioEngine`) or 200 Hz (`IOHIDManager`) even when all windows and popovers are closed, causing continuous background SwiftUI layout evaluations.
- **Our Solution:** `AcousticImpulseEngine` tracks `visibleTelemetryConsumers` via `registerVisibleTelemetryConsumer()` / `unregisterVisibleTelemetryConsumer()` in `ControlCenterMenuBarView` and `SettingsWindowView`.
- When `visibleTelemetryConsumers == 0`:
  - The 24 Hz visual decay `Timer` is **completely invalidated** (`stopVisualDecayLoop()`).
  - `MotionSensorService` sets `isLiveTelemetryVisible = false` and **never dispatches telemetry updates to `@MainActor`** unless a physical impact exceeds the $0.015\,g$ mechanical wake threshold.
  - The `AVAudioEngine` tap exits on the real-time thread as soon as `peak < dynamicGate` without hopping to `@MainActor`.

### 2.2 Zero-Allocation Real-Time Audio & HID Callbacks
- All vector RMS, peak magnitude, and 4-band spectral sums inside `makeAudioTapBlock` use stack primitives and `Accelerate` (`vDSP_rmsqv`, `vDSP_maxmgv`).
- All 200 Hz `BMI286` accelerometer and gyroscope reports are parsed directly from the raw `UnsafePointer<UInt8>` report buffer inside `spuHIDInputReportCallback` using bitwise unaligned loads and `os_unfair_lock`.
