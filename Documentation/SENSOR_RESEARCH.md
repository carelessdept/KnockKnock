# SENSOR RESEARCH — Apple Silicon SPU (`BMI286` & `ma981`) + Acoustic Transients

Empirical hardware research performed on **`Mac17,3` (Apple M5 MacBook Air, macOS 27.0.1 `26A434`)**.

---

## 1. Apple Silicon SPU HID Discovery (`AppleSPUHIDDriver` / `AppleSPUHIDDevice`)

Unlike legacy Intel Macs that used the `SMCMotionSensor` Sudden Motion Sensor, Apple Silicon MacBooks attach their inertial measurement unit (IMU) and lid angle sensor directly to the **System Processing Unit (SPU)** via `AppleSPUHIDDriver` and `AppleSPUHIDDevice`.

### 1.1 Waking the SPU Inertial Sensors from User Space
By default, `AppleSPUHIDDriver` leaves the accelerometer and gyroscope in low-power standby. We discovered and verified that a standard user-space process (**with zero root privileges and zero private entitlements**) can wake both sensors at **200 Hz** by setting three `IORegistryEntry` properties on every `AppleSPUHIDDriver` service before opening `IOHIDManager`:

```swift
IORegistryEntrySetCFProperty(entry, "SensorPropertyReportingState" as CFString, 1 as CFNumber)
IORegistryEntrySetCFProperty(entry, "SensorPropertyPowerState" as CFString, 1 as CFNumber)
IORegistryEntrySetCFProperty(entry, "ReportInterval" as CFString, 5000 as CFNumber) // 5,000 µs = 200 Hz
```

---

## 2. Empirical HID Report Layouts

### 2.1 Bosch `BMI286` 3-Axis Accelerometer
- **IOKit Matching:** `PrimaryUsagePage = 0xFF00` (`65280`), `PrimaryUsage = 3`, `Product = "accel"`.
- **Report Size:** `22 bytes` at `200.0 Hz`.
- **Byte Layout:**
  - Bytes `0..5`: Report header & SPU timestamp Counter.
  - Bytes `6..9`: `X` acceleration (`Int32` little-endian, Q16.16 fixed-point: divide by `65536.0` for $g$).
  - Bytes `10..13`: `Y` acceleration (`Int32` little-endian, divide by `65536.0` for $g$).
  - Bytes `14..17`: `Z` acceleration (`Int32` little-endian, divide by `65536.0` for $g$).
  - Bytes `18..21`: Status/temperature trailer.
- **Resting Baseline on Flat Desk:**
  - $a_x \approx -0.0106\,g$, $a_y \approx +0.0116\,g$, $a_z \approx -0.9951\,g$ ($|\vec{a}| = 0.9952\,g$).
- **Physical Knock Signature:**
  - High-pass 3D jerk $|\Delta \vec{a}| = \sqrt{\Delta a_x^2 + \Delta a_y^2 + \Delta a_z^2}$ spikes to **$0.045\,g \text{--} 0.240\,g$** within a single $5\,\text{ms}$ sample!
  - Loud airborne human speech, clapping, or music produces **$|\Delta \vec{a}| < 0.002\,g$** on the `BMI286`, providing a >20× signal-to-noise separation between physical knocks and airborne room audio.

### 2.2 Bosch `BMI286` 3-Axis Gyroscope
- **IOKit Matching:** `PrimaryUsagePage = 0xFF00` (`65280`), `PrimaryUsage = 9`, `Product = "gyro"`.
- **Report Size:** `22 bytes` at `200.0 Hz`.
- **Byte Layout:** `Int32` little-endian at byte offsets `6, 10, 14` divided by `65536.0` gives pitch, roll, and yaw angular velocity in $\text{deg/s}$ ($^\circ/\text{s}$).
- **Spatial Zone Discrimination:**
  - Knocking the **Left Palm Rest** induces a downward torque on the left side of the chassis ($\omega_{\text{roll}} \le -2.4^\circ/\text{s}$).
  - Knocking the **Right Palm Rest** induces an opposite torque ($\omega_{\text{roll}} \ge +2.4^\circ/\text{s}$).
  - Knocking near the **Trackpad Center or Display Lid** produces high Z-jerk with low roll torque ($|\omega_{\text{roll}}| < 2.4^\circ/\text{s}$).

### 2.3 Apple SPU `ma981` Lid Angle Sensor
- **IOKit Matching:** `PrimaryUsagePage = 0x0020` (`kHIDPage_Sensor`), `PrimaryUsage = 138` (`0x8A`, Orientation: Tilt/Hinge), `Product = "las"`.
- **Report Size:** `3 bytes`.
- **Byte Layout:**
  - Byte `0`: Report ID (`0x01`).
  - Bytes `1..2`: `UInt16` little-endian (`UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)`) representing exact display lid angle in degrees (`1°` resolution, verified live at `111°` and `84°`).

---

## 3. Built-In Microphone Acoustic Transient Signatures (`48 kHz`)

| Acoustic Source | Crest Factor ($\text{Peak}/\text{RMS}$) | Dominant Spectral Band | `BMI286` Motion Jerk | Classifier Decision |
| :--- | :--- | :--- | :--- | :--- |
| **Unibody Chassis Knock** | $5.2 \text{--} 14.0$ | Low-Mid ($80\text{--}450\,\text{Hz}$ structural mode) | $0.045\text{--}0.240\,g$ | **Accepted (`fusedChassisKnock`)** |
| **Crisp Finger Snap** | $5.8 \text{--} 16.5$ | Upper-Mid ($2.2\text{--}5.5\,\text{kHz}$ air snap) | $< 0.003\,g$ | **Accepted (`fingerSnap`)** |
| **Human Speech / Music** | $1.5 \text{--} 3.8$ (multi-buffer) | Vocal Formants ($450\text{--}2200\,\text{Hz}$) | $< 0.002\,g$ | **Rejected (`sustainedAudioRejected`)** |
| **Keyboard Typing** | $4.5 \text{--} 9.0$ | Broadband keycap click | $0.015\text{--}0.055\,g$ | **Suppressed (`typingOrMouseActive`)** |
