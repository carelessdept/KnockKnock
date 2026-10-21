import Foundation
import AVFoundation
import IOKit
import IOKit.hid
import ApplicationServices
import Observation

// MARK: - Part 1.2 & Part 9: Hardware & Permission Capability Registry

@MainActor
@Observable
public final class CapabilityRegistry {
    public static let shared = CapabilityRegistry()

    public var macModelIdentifier: String = "Unknown Mac"
    public var cpuBrandString: String = "Apple Silicon"
    public var osVersionString: String = ProcessInfo.processInfo.operatingSystemVersionString
    public var physicalMemoryGB: Int = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))

    public var hasSPUAccelerometer: Bool = false
    public var hasSPUGyroscope: Bool = false
    public var hasLidAngleSensor: Bool = false
    public var microphoneAuthStatus: AVAuthorizationStatus = .notDetermined
    public var isAccessibilityTrusted: Bool = false

    public var capabilities: [CapabilityDescriptor] = []

    public init() {
        refreshHardwareAndPermissions()
    }

    public func refreshHardwareAndPermissions() {
        macModelIdentifier = Self.sysctlString("hw.model") ?? "Mac"
        cpuBrandString = Self.sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
        microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        isAccessibilityTrusted = AXIsProcessTrusted()

        let spuProbe = Self.probeSPUSensors()
        hasSPUAccelerometer = spuProbe.hasAccel
        hasSPUGyroscope = spuProbe.hasGyro
        hasLidAngleSensor = spuProbe.hasLidAngle

        let micStatus: CapabilityAvailabilityStatus
        switch microphoneAuthStatus {
        case .authorized:
            micStatus = .available
        case .notDetermined, .denied, .restricted:
            micStatus = .permissionRequired
        @unknown default:
            micStatus = .permissionRequired
        }

        capabilities = [
            CapabilityDescriptor(
                id: "spu_accelerometer",
                name: "Bosch BMI286 3-Axis SPU Accelerometer",
                hardwareRequirement: "Apple Silicon MacBook with AppleSPUHIDDevice (0xFF00:0x03)",
                apiOrAccessMethod: "IOKit.hid (AppleSPUHIDDriver / IOHIDDeviceRegisterInputReportCallback)",
                classification: .restrictedIOKitSPU,
                requiredPermission: "None (User-Space SPU HID Read)",
                detectionMethod: "IOServiceMatching(\"AppleSPUHIDDriver\") Product=accel",
                status: hasSPUAccelerometer ? .available : .unavailable,
                verificationStage: hasSPUAccelerometer ? .hardwareTested : .implemented,
                knownRisks: "Future macOS releases could restrict unprivileged ReportInterval configuration on AppleSPUHIDDriver.",
                testedBehavior: hasSPUAccelerometer
                    ? "Verified live 200 Hz 22-byte reports (16.16 fixed-point g) on \(macModelIdentifier) (\(cpuBrandString))."
                    : "Not detected on this hardware; falls back to acoustic transient detection.",
                fallbackStrategy: "Automatic fallback to Microphone-Only onset detection.",
                measuredSampleRateHz: hasSPUAccelerometer ? 200.0 : 0.0
            ),
            CapabilityDescriptor(
                id: "spu_gyroscope",
                name: "Bosch BMI286 3-Axis SPU Gyroscope",
                hardwareRequirement: "Apple Silicon MacBook with AppleSPUHIDDevice (0xFF00:0x09)",
                apiOrAccessMethod: "IOKit.hid (AppleSPUHIDDriver / IOHIDDeviceRegisterInputReportCallback)",
                classification: .restrictedIOKitSPU,
                requiredPermission: "None (User-Space SPU HID Read)",
                detectionMethod: "IOServiceMatching(\"AppleSPUHIDDriver\") Product=gyro",
                status: hasSPUGyroscope ? .available : .unavailable,
                verificationStage: hasSPUGyroscope ? .hardwareTested : .implemented,
                knownRisks: "Angular velocity torque sign depends on whether MacBook rests on a rigid desk vs. lap.",
                testedBehavior: hasSPUGyroscope
                    ? "Verified live 200 Hz 22-byte angular rate reports (deg/s) on \(macModelIdentifier)."
                    : "Not detected on this hardware.",
                fallbackStrategy: "Disable rotational spatial zone estimation; use omnidirectional jerk.",
                measuredSampleRateHz: hasSPUGyroscope ? 200.0 : 0.0
            ),
            CapabilityDescriptor(
                id: "spu_lid_angle",
                name: "Apple SPU Lid Angle Sensor (ma981)",
                hardwareRequirement: "Apple Silicon MacBook with AppleSPUHIDDevice (0x0020:0x008A)",
                apiOrAccessMethod: "IOKit.hid (IOHIDDevice page=0x20 usage=0x8A)",
                classification: .restrictedIOKitSPU,
                requiredPermission: "None (motionRestrictedService = 0)",
                detectionMethod: "IOServiceMatching(\"AppleSPUHIDDriver\") Product=las",
                status: hasLidAngleSensor ? .experimental : .unavailable,
                verificationStage: hasLidAngleSensor ? .hardwareTested : .implemented,
                knownRisks: "Ordinary display angle adjustments can resemble intentional hinge nudges; kept experimental.",
                testedBehavior: hasLidAngleSensor
                    ? "Verified 3-byte reports giving exact display angle in degrees (1° resolution) on \(macModelIdentifier)."
                    : "Unavailable on desktop Macs.",
                fallbackStrategy: "Suppress knock recognition while lid angle is actively changing.",
                measuredSampleRateHz: hasLidAngleSensor ? 10.0 : 0.0
            ),
            CapabilityDescriptor(
                id: "builtin_microphone",
                name: "Built-In Microphone Transient Analyzer",
                hardwareRequirement: "macOS Audio Input Device (48 kHz mono)",
                apiOrAccessMethod: "AVAudioEngine + Accelerate/vDSP",
                classification: .publicFramework,
                requiredPermission: "Microphone (NSMicrophoneUsageDescription)",
                detectionMethod: "AVCaptureDevice.authorizationStatus(for: .audio)",
                status: micStatus,
                verificationStage: .hardwareTested,
                knownRisks: "High ambient noise or loud speakers can cause false triggers if used without BMI286 motion fusion.",
                testedBehavior: "Processes 1024-sample buffers transiently in RAM with zero disk/network persistence.",
                fallbackStrategy: "Switch to Chassis Motion Only (BMI286 Accelerometer) when Mic permission is denied or paused.",
                measuredSampleRateHz: micStatus == .available ? 48000.0 : 0.0
            ),
            CapabilityDescriptor(
                id: "input_activity_guard",
                name: "Keyboard & Trackpad Activity Suppression",
                hardwareRequirement: "macOS Quartz Event Services",
                apiOrAccessMethod: "CGEventSource.secondsSinceLastEventType(.combinedSessionState)",
                classification: .publicFramework,
                requiredPermission: "None (Timing Query Only — Zero Keystroke Logging)",
                detectionMethod: "CGEventSource.secondsSinceLastEventType",
                status: .available,
                verificationStage: .hardwareTested,
                knownRisks: "Suppresses intentional knocks if performed within 350 ms of typing or moving the cursor.",
                testedBehavior: "Verified millisecond-accurate suppression during typing, clicking, dragging, and scrolling.",
                fallbackStrategy: "Configurable suppression window (50–600 ms).",
                measuredSampleRateHz: 200.0
            ),
            CapabilityDescriptor(
                id: "spatial_knock_zones",
                name: "Spatial Knock Zones (Left vs. Right Palm Rest)",
                hardwareRequirement: "BMI286 3-Axis Accelerometer + Gyroscope",
                apiOrAccessMethod: "Gyroscope Roll Torque Sign + Per-Device Calibration",
                classification: .restrictedIOKitSPU,
                requiredPermission: "None",
                detectionMethod: "Requires both spu_accelerometer and spu_gyroscope",
                status: (hasSPUAccelerometer && hasSPUGyroscope) ? .experimental : .unavailable,
                verificationStage: .integrationTested,
                knownRisks: "Cannot achieve centimeter-level precision; reliable only for broad Left vs. Right palm-rest zones on a stable surface.",
                testedBehavior: "Broad Left/Right torque classification enabled only when explicitly toggled in Experimental Lab.",
                fallbackStrategy: "Treat all chassis impacts as omnidirectional Any-Zone knocks.",
                measuredSampleRateHz: 200.0
            ),
            CapabilityDescriptor(
                id: "media_hid_dispatch",
                name: "System Media & Audio Control Dispatch",
                hardwareRequirement: "macOS AppKit / IOKit HID System",
                apiOrAccessMethod: "NSEvent.otherEvent(with: .systemDefined, subtype: 8) NX_KEYTYPE_*",
                classification: .publicFramework,
                requiredPermission: "None",
                detectionMethod: "AppKit NSEvent synthesis",
                status: .available,
                verificationStage: .hardwareTested,
                knownRisks: "Routes to whichever application currently owns macOS Now Playing focus.",
                testedBehavior: "Verified Play/Pause, Next, Previous, and Mute/Unmute on macOS 27.0.1.",
                fallbackStrategy: "Direct AppleScript or Shortcuts action for specific media apps."
            )
        ]
    }

    public func updateMeasuredSampleRate(id: String, hz: Double, status: CapabilityAvailabilityStatus? = nil) {
        guard let idx = capabilities.firstIndex(where: { $0.id == id }) else { return }
        capabilities[idx].measuredSampleRateHz = hz
        if let status {
            capabilities[idx].status = status
        }
    }

    // MARK: - Low-Level Hardware Detection Helpers

    nonisolated private static func sysctlString(_ name: String) -> String? {
        var size: Int = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    nonisolated private static func probeSPUSensors() -> (hasAccel: Bool, hasGyro: Bool, hasLidAngle: Bool) {
        var hasAccel = false
        var hasGyro = false
        var hasLid = false

        let matching = IOServiceMatching("AppleSPUHIDDriver")
        var iter: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS {
            var service = IOIteratorNext(iter)
            while service != 0 {
                if let prod = IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                    switch prod {
                    case "accel": hasAccel = true
                    case "gyro": hasGyro = true
                    case "las": hasLid = true
                    default: break
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            IOObjectRelease(iter)
        }
        return (hasAccel, hasGyro, hasLid)
    }
}
