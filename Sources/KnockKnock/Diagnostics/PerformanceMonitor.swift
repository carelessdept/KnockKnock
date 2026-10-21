import Foundation
import Darwin.Mach

// MARK: - Part 8: Real Mach Kernel Performance, Memory & Latency Telemetry

@MainActor
public final class PerformanceMonitor {
    public static let shared = PerformanceMonitor()

    public private(set) var residentMemoryMB: Double = 0.0
    public private(set) var processCPUPercent: Double = 0.0
    public private(set) var meanCallbackMicros: Double = 28.0
    public private(set) var lastRecognitionLatencyMs: Double = 18.0
    public private(set) var processedFramesCount: Int = 0
    public private(set) var suppressedEventsCount: Int = 0

    private var lastCPUTimeSeconds: Double = 0.0
    private var lastWallTimeSeconds: TimeInterval = ProcessInfo.processInfo.systemUptime

    public init() {
        sampleProcessMetrics()
    }

    public func recordCallbackExecution(durationMicros: Double) {
        processedFramesCount += 1
        meanCallbackMicros = meanCallbackMicros * 0.90 + durationMicros * 0.10
    }

    public func recordSuppression() {
        suppressedEventsCount += 1
    }

    public func recordRecognitionLatency(ms: Double) {
        lastRecognitionLatencyMs = ms
    }

    /// Samples actual resident memory (RSS) and process CPU utilization via Mach task_info.
    public func sampleProcessMetrics() {
        let nowWall = ProcessInfo.processInfo.systemUptime
        let wallDelta = max(nowWall - lastWallTimeSeconds, 0.05)

        // 1. Resident Memory (MACH_TASK_BASIC_INFO)
        var basicInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kerr = withUnsafeMutablePointer(to: &basicInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            residentMemoryMB = Double(basicInfo.resident_size) / (1024.0 * 1024.0)
        }

        // 2. Thread CPU Time (TASK_THREAD_TIMES_INFO)
        var threadTimes = task_thread_times_info_data_t()
        var threadTimesCount = mach_msg_type_number_t(
            MemoryLayout<task_thread_times_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let tkerr = withUnsafeMutablePointer(to: &threadTimes) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadTimesCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &threadTimesCount)
            }
        }
        if tkerr == KERN_SUCCESS {
            let userSec = Double(threadTimes.user_time.seconds) + Double(threadTimes.user_time.microseconds) / 1_000_000.0
            let sysSec = Double(threadTimes.system_time.seconds) + Double(threadTimes.system_time.microseconds) / 1_000_000.0
            let totalCPU = userSec + sysSec
            if lastCPUTimeSeconds > 0 {
                let cpuDelta = max(0.0, totalCPU - lastCPUTimeSeconds)
                processCPUPercent = min(100.0, (cpuDelta / wallDelta) * 100.0)
            }
            lastCPUTimeSeconds = totalCPU
            lastWallTimeSeconds = nowWall
        }
    }
}
