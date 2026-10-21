# TEST PLAN — Unit, Deterministic Replay & Hardware Acceptance

---

## 1. Automated Test Suite (`swift test`)

Located in [`Tests/KnockKnockTests/AcousticClassifierTests.swift`](file:///Users/janardhanreddy/Downloads/KnockKnock/Tests/KnockKnockTests/AcousticClassifierTests.swift). All 10 test suites run deterministically in $< 80\,\text{ms}$:

| Test Name | Category | Verified Invariants |
| :--- | :--- | :--- |
| `testSensorFusionImpulseClassification` | Unit (Part 13.1) | Verifies corroborated `BMI286` + `80–450 Hz` knock classification (`fusedChassisKnock`) vs airborne `2.2–5.5 kHz` finger snap (`fingerSnap`). |
| `testAccelerometerPrimaryMode` | Unit (Part 13.1) | Verifies **Accelerometer-Primary (Motion-Only) Mode** accepts physical knocks with `peak = 0.0` (Microphone OFF) and rejects loud airborne sound (`peak = 0.55`) lacking chassis motion. |
| `testFalsePositiveSuppressionPipeline` | Unit (Part 13.1) | Verifies active typing guard (`msSinceLastKeystroke < 350 ms`), sustained audio envelope rejection, low crest factor rejection, and vocal formant rejection. |
| `testSpatialZoneEstimation` | Unit (Part 13.1) | Verifies `BMI286` gyroscope Y-axis roll impulse discrimination between `.leftPalmRest`, `.rightPalmRest`, and `.centerOrLid`. |
| `testSecretRhythmDTWMatching` | Unit (Part 13.1) | Verifies tempo-invariant 4-beat cadence matching across fast ($400/200/200\,\text{ms}$) and slow ($700/350/350\,\text{ms}$) tempos using normalized ratios + 1D Dynamic Time Warping (`dtwNormalizedDistance`). |
| `testDeterministicReplayDoubleVsTripleKnockArbitration` | Replay (Part 13.2) | Replays synthetic multi-sensor streams through `DeterministicReplayEngine` and proves a 3-knock sequence triggers **only** `.tripleKnock` while incrementing `.conflictArbitrated` (`1`) and never double-firing `.doubleKnock`. |
| `testDeterministicReplayMultimodalAndSpatialZones` | Replay (Part 13.2) | Verifies `isTrackpadHeld = true` dispatches `.trackpadHoldDoubleKnock` and positive gyro roll dispatches `.rightZoneDoubleKnock`. |
| `testDeterministicReplayNegativeStreams` | Replay (Part 13.2) | Replays rapid keyboard typing, continuous speech/music, and isolated single desk bumps; asserts `recognizedGestures.isEmpty`. |
| `testConfigurationValidationAndCorruptionRecovery` | Persistence (Part 8) | Verifies out-of-range thresholds are clamped with structured warnings and corrupted JSON payloads recover cleanly to schema v2 defaults without crashing. |
| `testPerformanceMonitorAndCapabilityRegistry` | Telemetry (Part 8) | Verifies Mach kernel `task_info` resident memory MB, CPU %, and `CapabilityRegistry` hardware discovery on the host Mac. |

---

## 2. False-Positive Resistance Matrix

| Everyday Scenario | Primary Guard Mechanism | Secondary Guard Mechanism | Expected False Triggers |
| :--- | :--- | :--- | :--- |
| **Fast Keyboard Typing** | `CGEventSource` Input Guard ($350\,\text{ms}$ window) | Cadence pair requirement | **0** |
| **Trackpad Clicking & Dragging** | `CGEventSource` mouse/button activity guard | Single-impulse isolation filter | **0** |
| **Loud Speech / Zoom Call** | `BMI286` Accelerometer Jerk Gate ($\ge 0.032\,g$) | Multi-buffer sustained audio envelope gate | **0** |
| **Music Playing on MacBook Speakers** | `BMI286` Accelerometer Jerk Gate + Crest Factor ($\ge 4.2$) | Mid-vocal spectral ratio rejection | **0** |
| **Setting Down a Coffee Mug on Desk** | Isolated Single-Tap Rejection (requires 2+ matched pulses within $125\text{--}480\,\text{ms}$) | Spectral & crest consistency | **0** |
| **Adjusting Display Lid Angle** | `ma981` Lid Angle Sensor movement guard | Single-impulse isolation filter | **0** |
