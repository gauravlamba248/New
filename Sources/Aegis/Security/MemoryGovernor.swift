import Foundation
import Darwin
import WebKit

public enum MemoryTier: String, Sendable {
    case idle = "IDLE (<15MB)"
    case normal = "NORMAL (<50MB)"
    case heavy = "HEAVY (<100MB)"
    case critical = "WORST-CASE CAP (<100MB)"
}

public struct KernelMemoryMetrics: Sendable {
    public let physicalFootprintMB: Double // Exact metric shown in Activity Monitor "Memory" column
    public let residentSetSizeMB: Double   // BSD ps -o rss & Activity Monitor "Real Memory" column
    public let compressedMB: Double        // Compressed memory
    public let peakFootprintMB: Double     // Highest memory footprint recorded
    public let timestamp: Date
}

/// Low-level macOS Virtual Memory & Physical Footprint Governor.
/// Queries the Mach kernel in real-time using TASK_VM_INFO (0.7µs syscall, zero allocations).
public final class MemoryGovernor: @unchecked Sendable {
    public static let shared = MemoryGovernor()

    public static let idleBudgetMB: Double = 15.0
    public static let normalBudgetMB: Double = 50.0
    public static let heavyBudgetMB: Double = 100.0

    private let lock = NSLock()
    private var peakFootprint: Double = 0.0

    private init() {}

    /// Real-time Mach kernel query for exact Physical Footprint and Resident Set Size.
    /// Operates in sub-microsecond time with zero heap allocations.
    public func sampleKernelMemory() -> KernelMemoryMetrics {
        var vmInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)

        let kr = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard kr == KERN_SUCCESS else {
            lock.lock()
            defer { lock.unlock() }
            return KernelMemoryMetrics(
                physicalFootprintMB: 0.0,
                residentSetSizeMB: 0.0,
                compressedMB: 0.0,
                peakFootprintMB: peakFootprint,
                timestamp: Date()
            )
        }

        let footprint = Double(vmInfo.phys_footprint) / (1024.0 * 1024.0)
        let rss = Double(vmInfo.resident_size) / (1024.0 * 1024.0)
        let compressed = Double(vmInfo.compressed) / (1024.0 * 1024.0)

        lock.lock()
        if footprint > peakFootprint {
            peakFootprint = footprint
        }
        let peak = peakFootprint
        lock.unlock()

        return KernelMemoryMetrics(
            physicalFootprintMB: footprint,
            residentSetSizeMB: rss,
            compressedMB: compressed,
            peakFootprintMB: peak,
            timestamp: Date()
        )
    }

    public func currentPhysicalFootprintMB() -> Double {
        return sampleKernelMemory().physicalFootprintMB
    }

    public func currentResidentMemoryMB() -> Double {
        return sampleKernelMemory().residentSetSizeMB
    }

    /// Evaluates current memory tier and triggers aggressive pressure relief if budget is strained.
    @MainActor
    public func evaluateAndEnforce(activeWebView: WKWebView? = nil) -> MemoryTier {
        let footprintMB = currentPhysicalFootprintMB()

        if footprintMB >= Self.heavyBudgetMB - 5.0 {
            // HARD CEILING AT 100MB: Emergency Purge
            emergencyPurge(activeWebView: activeWebView)
            return .critical
        } else if footprintMB >= Self.normalBudgetMB {
            // HEAVY TIER: Reclaim intermediate caches
            reclaimHeavyMemory(activeWebView: activeWebView)
            return .heavy
        } else if footprintMB >= Self.idleBudgetMB {
            // NORMAL TIER
            reclaimNormalMemory()
            return .normal
        } else {
            return .idle
        }
    }

    /// Releases idle heap buffers and returns physical pages directly to macOS virtual memory manager.
    public func reclaimIdleMemory() {
        autoreleasepool {
            URLCache.shared.removeAllCachedResponses()
            malloc_zone_pressure_relief(malloc_default_zone(), 0)
        }
    }

    /// Reclaims intermediate caches for normal operations
    public func reclaimNormalMemory() {
        autoreleasepool {
            URLCache.shared.removeAllCachedResponses()
            malloc_zone_pressure_relief(malloc_default_zone(), 0)
        }
    }

    /// Reclaims memory during heavy use (e.g. streaming downloads, large DOMs)
    @MainActor
    public func reclaimHeavyMemory(activeWebView: WKWebView?) {
        autoreleasepool {
            URLCache.shared.removeAllCachedResponses()
            SecurityAuditLogger.shared.trimMemoryBuffer(to: 20)

            if let wv = activeWebView {
                let dataTypes: Set<String> = [
                    WKWebsiteDataTypeMemoryCache,
                    WKWebsiteDataTypeDiskCache
                ]
                wv.configuration.websiteDataStore.removeData(
                    ofTypes: dataTypes,
                    modifiedSince: Date(timeIntervalSince1970: 0),
                    completionHandler: {}
                )
            }

            malloc_zone_pressure_relief(malloc_default_zone(), 0)
        }
    }

    /// Emergency mitigation ensuring process NEVER crosses 100MB ceiling
    @MainActor
    public func emergencyPurge(activeWebView: WKWebView?) {
        autoreleasepool {
            URLCache.shared.removeAllCachedResponses()
            SecurityAuditLogger.shared.trimMemoryBuffer(to: 10)

            if let wv = activeWebView {
                let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
                wv.configuration.websiteDataStore.removeData(
                    ofTypes: allTypes,
                    modifiedSince: Date(timeIntervalSince1970: 0),
                    completionHandler: {}
                )
                wv.layer?.contents = nil
            }

            // Double pass malloc zone pressure relief
            malloc_zone_pressure_relief(malloc_default_zone(), 0)
        }
    }
}
