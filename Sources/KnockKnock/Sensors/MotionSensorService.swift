import Foundation
import IOKit
import IOKit.hid

// MARK: - Part 5.2: Real Hardware AppleSPUHIDDevice Motion & Lid Angle Service (BMI286 + ma981)

@MainActor
public final class MotionSensorService {
    public private(set) var isRunning: Bool = false
    public private(set) var accelSampleRateHz: Double = 0.0
    public private(set) var gyroSampleRateHz: Double = 0.0
    public private(set) var lidAngleDegrees: Double = 0.0
    public private(set) var isLidMoving: Bool = false

    public private(set) var latestAccelX: Double = 0.0
    public private(set) var latestAccelY: Double = 0.0
    public private(set) var latestAccelZ: Double = -1.0
    public private(set) var latestJerkG: Double = 0.0
    public private(set) var latestGyroRollDegPerSec: Double = 0.0

    /// When false, live waveform telemetry updates to the UI are throttled to near-zero unless an impact occurs.
    public var isLiveTelemetryVisible: Bool = false

    /// Called immediately on @MainActor when a mechanical chassis impact exceeds the minimum jerk gate.
    public var onMechanicalImpact: ((MotionSample) -> Void)?

    /// Called when a deliberate small-angle lid nudge (+-4 deg within 650ms) is detected.
    public var onHingeNudgeDetected: ((Double) -> Void)?

    private var hidManager: IOHIDManager?
    private var deviceContexts: [SPUDeviceContext] = []
    private let processor = NonisolatedSPUProcessor()

    public init() {}

    public func start() -> Bool {
        stop()

        // 1. Wake AppleSPUHIDDriver sensors in user-space (BMI286 accel/gyro + ma981 las)
        Self.configureSPUDriverReporting(enabled: true, intervalMicros: 5000)

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchings: [[String: Any]] = [
            [kIOHIDPrimaryUsagePageKey: 0xFF00, kIOHIDPrimaryUsageKey: 3],   // BMI286 accel
            [kIOHIDPrimaryUsagePageKey: 0xFF00, kIOHIDPrimaryUsageKey: 9],   // BMI286 gyro
            [kIOHIDPrimaryUsagePageKey: 0x0020, kIOHIDPrimaryUsageKey: 138]  // ma981 lid angle sensor
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchings as CFArray)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openStatus == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              !devices.isEmpty else {
            return false
        }

        processor.bind(service: self)
        var attachedCount = 0

        for dev in devices {
            let ioClass = IOHIDDeviceGetProperty(dev, "IOClass" as CFString) as? String ?? ""
            guard ioClass == "AppleSPUHIDDevice" else { continue }
            let product = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String ?? ""
            guard product == "accel" || product == "gyro" || product == "las" else { continue }

            guard IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
                continue
            }

            let ctx = SPUDeviceContext(product: product, processor: processor)
            deviceContexts.append(ctx)

            IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDDeviceRegisterInputReportCallback(
                dev,
                ctx.reportBuffer,
                ctx.bufferCapacity,
                spuHIDInputReportCallback,
                Unmanaged.passUnretained(ctx).toOpaque()
            )
            attachedCount += 1
        }

        guard attachedCount > 0 else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }

        hidManager = manager
        isRunning = true
        return true
    }

    public func stop() {
        if let manager = hidManager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidManager = nil
        deviceContexts.removeAll()
        isRunning = false
        accelSampleRateHz = 0
        gyroSampleRateHz = 0
    }

    fileprivate func handleDecodedImpact(_ sample: MotionSample, accelHz: Double, gyroHz: Double) {
        latestAccelX = sample.accelX
        latestAccelY = sample.accelY
        latestAccelZ = sample.accelZ
        latestJerkG = max(sample.jerkMagnitude, latestJerkG * 0.75)
        latestGyroRollDegPerSec = sample.gyroY
        accelSampleRateHz = accelHz
        gyroSampleRateHz = gyroHz
        onMechanicalImpact?(sample)
    }

    fileprivate func handlePeriodicTelemetry(
        ax: Double,
        ay: Double,
        az: Double,
        jerk: Double,
        gyroY: Double,
        accelHz: Double,
        gyroHz: Double
    ) {
        latestAccelX = ax
        latestAccelY = ay
        latestAccelZ = az
        latestJerkG = max(jerk, latestJerkG * 0.80)
        latestGyroRollDegPerSec = gyroY
        accelSampleRateHz = accelHz
        gyroSampleRateHz = gyroHz
    }

    fileprivate func handleLidAngleUpdate(degrees: Double, delta: Double) {
        let prev = lidAngleDegrees
        lidAngleDegrees = degrees
        if prev > 0 && abs(degrees - prev) >= 1.0 {
            isLidMoving = true
            if abs(delta) >= 3.0 && abs(delta) <= 8.0 {
                onHingeNudgeDetected?(delta)
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(420))
                self?.isLidMoving = false
            }
        }
    }

    nonisolated private static func configureSPUDriverReporting(enabled: Bool, intervalMicros: Int) {
        let matching = IOServiceMatching("AppleSPUHIDDriver")
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else { return }
        var service = IOIteratorNext(iter)
        while service != 0 {
            let stateVal = (enabled ? 1 : 0) as CFNumber
            _ = IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, stateVal)
            _ = IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, stateVal)
            _ = IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, intervalMicros as CFNumber)
            IOObjectRelease(service)
            service = IOIteratorNext(iter)
        }
        IOObjectRelease(iter)
    }
}

// MARK: - Nonisolated High-Frequency (200 Hz) SPU Report Decoder

private final class SPUDeviceContext: @unchecked Sendable {
    let product: String
    let processor: NonisolatedSPUProcessor
    let bufferCapacity = 64
    let reportBuffer: UnsafeMutablePointer<UInt8>

    init(product: String, processor: NonisolatedSPUProcessor) {
        self.product = product
        self.processor = processor
        self.reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferCapacity)
        self.reportBuffer.initialize(repeating: 0, count: bufferCapacity)
    }

    deinit {
        reportBuffer.deallocate()
    }
}

private let spuHIDInputReportCallback: IOHIDReportCallback = { context, result, _, _, _, report, reportLength in
    guard result == kIOReturnSuccess, let context else { return }
    let devCtx = Unmanaged<SPUDeviceContext>.fromOpaque(context).takeUnretainedValue()
    devCtx.processor.ingestReport(
        product: devCtx.product,
        bytes: report,
        length: reportLength
    )
}

private final class NonisolatedSPUProcessor: @unchecked Sendable {
    private weak var service: MotionSensorService?

    // Exponential moving average for gravity vector removal
    private var gravX: Double = 0.0
    private var gravY: Double = 0.0
    private var gravZ: Double = -1.0
    private var isInitialized: Bool = false

    // Latest gyroscope readings (deg/s)
    private var gyroX: Double = 0.0
    private var gyroY: Double = 0.0
    private var gyroZ: Double = 0.0

    // Rate measurement counters
    private var accelCounter: Int = 0
    private var gyroCounter: Int = 0
    private var rateWindowStart: TimeInterval = ProcessInfo.processInfo.systemUptime
    private var measuredAccelHz: Double = 200.0
    private var measuredGyroHz: Double = 200.0
    private var lastUIUpdateTime: TimeInterval = 0
    private var lastImpactTime: TimeInterval = 0

    func bind(service: MotionSensorService) {
        self.service = service
    }

    func ingestReport(product: String, bytes: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let now = ProcessInfo.processInfo.systemUptime

        if product == "las" && length >= 3 {
            let rawAngle = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
            let deg = Double(rawAngle)
            guard deg >= 0 && deg <= 180 else { return }
            Task { @MainActor [weak service] in
                guard let service else { return }
                let delta = deg - service.lidAngleDegrees
                service.handleLidAngleUpdate(degrees: deg, delta: delta)
            }
            return
        }

        guard length == 22 else { return }
        let rawPtr = UnsafeRawPointer(bytes)
        let rx = rawPtr.loadUnaligned(fromByteOffset: 6, as: Int32.self)
        let ry = rawPtr.loadUnaligned(fromByteOffset: 10, as: Int32.self)
        let rz = rawPtr.loadUnaligned(fromByteOffset: 14, as: Int32.self)

        let vx = Double(rx) / 65536.0
        let vy = Double(ry) / 65536.0
        let vz = Double(rz) / 65536.0

        if product == "gyro" {
            gyroCounter += 1
            gyroX = vx
            gyroY = vy
            gyroZ = vz
            return
        }

        guard product == "accel" else { return }
        accelCounter += 1

        let elapsed = now - rateWindowStart
        if elapsed >= 1.0 {
            measuredAccelHz = Double(accelCounter) / elapsed
            measuredGyroHz = Double(gyroCounter) / elapsed
            accelCounter = 0
            gyroCounter = 0
            rateWindowStart = now
        }

        if !isInitialized {
            gravX = vx
            gravY = vy
            gravZ = vz
            isInitialized = true
            return
        }

        // High-pass jerk calculation: compare instantaneous acceleration against low-pass gravity
        let dx = vx - gravX
        let dy = vy - gravY
        let dz = vz - gravZ
        let jerk = (dx * dx + dy * dy + dz * dz).squareRoot()

        // Update gravity baseline slowly (alpha = 0.08)
        gravX = gravX * 0.92 + vx * 0.08
        gravY = gravY * 0.92 + vy * 0.08
        gravZ = gravZ * 0.92 + vz * 0.08

        let currentGyroX = gyroX
        let currentGyroY = gyroY
        let currentGyroZ = gyroZ
        let aHz = measuredAccelHz
        let gHz = measuredGyroHz

        // Lightweight gate before hopping to @MainActor:
        // 1. If jerk >= 0.015g and refractory > 75ms, dispatch real mechanical impact immediately.
        if jerk >= 0.015 && (now - lastImpactTime) >= 0.075 {
            lastImpactTime = now
            let zone = AcousticSignalMath.estimateSpatialZone(gyroRollDegPerSec: currentGyroY)
            let sample = MotionSample(
                timestamp: now,
                accelX: vx,
                accelY: vy,
                accelZ: vz,
                gyroX: currentGyroX,
                gyroY: currentGyroY,
                gyroZ: currentGyroZ,
                jerkMagnitude: jerk,
                estimatedZone: zone
            )
            Task { @MainActor [weak service] in
                service?.handleDecodedImpact(sample, accelHz: aHz, gyroHz: gHz)
            }
            return
        }

        // 2. Otherwise only update @MainActor telemetry at 12 Hz if a telemetry view is open.
        if (now - lastUIUpdateTime) >= 0.083 {
            lastUIUpdateTime = now
            Task { @MainActor [weak service] in
                guard let service, service.isLiveTelemetryVisible else { return }
                service.handlePeriodicTelemetry(
                    ax: vx,
                    ay: vy,
                    az: vz,
                    jerk: jerk,
                    gyroY: currentGyroY,
                    accelHz: aHz,
                    gyroHz: gHz
                )
            }
        }
    }
}
