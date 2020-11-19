import Foundation

/// An object that observes memory usage periodically or on-demand.
/// - Note: Used via `shared`.
public class MemoryObserver {

    public static let shared = MemoryObserver()

    /// Information about current memory usage.
    public var currentMemory: MemoryInfo? {
        return try? fetchMemoryInfo()
    }

    private var timer: Timer?

    private var interval: ObservationInterval?

    private init() {}

    /// Starts observation of memory usage.
    /// Updates will be posted with `MemoryObserver.Notification.didChange` notification.
    /// - Parameter interval: An interval at which memory usage information should be updated.
    public func startObserving(interval: ObservationInterval = .default) {
        guard timer == nil || self.interval != interval else { return }
        self.interval = interval
        timer = Timer.scheduledTimer(timeInterval: interval.timeInterval,
                                     target: self,
                                     selector: #selector(reportMemory),
                                     userInfo: nil,
                                     repeats: true)
        guard let memory = currentMemory else { return }
        notify(memory)
    }

    /// Stops observation of memory usage.
    public func stopObserving() {
        timer?.invalidate()
        interval = nil
        timer = nil
    }

    @objc
    private func reportMemory() {
        guard let memory = currentMemory else { return }
        notify(memory)
    }

    private func fetchMemoryInfo() throws -> MemoryInfo {
        let basicInfo = try fetchInfo(withRequest: KernelRequest(info: mach_task_basic_info(),
                                                                 flavor: task_flavor_t(MACH_TASK_BASIC_INFO)))
        let vmInfo = try fetchInfo(withRequest: KernelRequest(info: task_vm_info_data_t(),
                                                              flavor: task_flavor_t(TASK_VM_INFO)))

        let residentSize = MemorySize(bytes: basicInfo.resident_size)
        let maxResidentSize = MemorySize(bytes: basicInfo.resident_size_max)
        let virtualSize = MemorySize(bytes: basicInfo.virtual_size)
        let usedSize = MemorySize(bytes: vmInfo.internal + vmInfo.compressed)
        let totalSize = MemorySize(bytes: ProcessInfo.processInfo.physicalMemory)

        return MemoryInfo(resident: residentSize,
                          maxResident: maxResidentSize,
                          virtual: virtualSize,
                          total: totalSize,
                          used: usedSize)
    }

}

// MARK: - ObservationQuality
public extension MemoryObserver {

    enum ObservationInterval {

        /// Refresh memory info almost in real-time every 100 ms.
        case live

        /// Refresh memory info every half of a second.
        case frequent

        /// Refresh memory info every second.
        case `default`

        /// Refresh memory info every 5 seconds.
        case deferred

        fileprivate var timeInterval: TimeInterval {
            switch self {
            case .live: return 0.1
            case .frequent: return 0.5
            case .default: return 1.0
            case .deferred: return 5.0
            }
        }
    }
}

// MARK: - Kernel
private extension MemoryObserver {

    struct KernelRequest<InfoType> {

        let info: InfoType

        let flavor: task_flavor_t
    }

    private func errorFromKernel(_ kernel: kern_return_t) -> String {
        return String(cString: mach_error_string(kernel), encoding: .ascii) ?? "unknown error"
    }

    func fetchInfo<InfoType>(withRequest request: KernelRequest<InfoType>) throws -> InfoType {
        var info = request.info
        let count = MemoryLayout<InfoType>.size / MemoryLayout<natural_t>.size

        var infoSize = mach_msg_type_number_t(count)

        let kern: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          request.flavor,
                          $0,
                          &infoSize)
            }
        }

        guard kern == KERN_SUCCESS else { throw MemoryError.failure(errorFromKernel(kern)) }

        return info
    }
}

// MARK: - Notification
public extension MemoryObserver {

    /// Notifications posted by `MemoryObserver`.
    enum Notification: String {

        /// Notification posted when memory information gets updated.
        /// - Parameter memoryInfo: A `MemoryInfo` object containing latest memory usage information.
        case didUpdate = "MemoryObserver.DidUpdate"

        public var name: Foundation.Notification.Name {
            return Foundation.Notification.Name(rawValue: rawValue)
        }

        public enum UserInfoKey: String, Hashable {

            case memoryInfoKey = "memoryInfo"

            public var hashValue: Int { return rawValue.hashValue }
        }
    }

    fileprivate func notify(_ memoryInfo: MemoryInfo) {
        DispatchQueue.global().async {
            NotificationCenter.default.post(name: Notification.didUpdate.name,
                                            object: self,
                                            userInfo: [Notification.UserInfoKey.memoryInfoKey: memoryInfo])
        }
    }
}

// MARK: - MemoryError
public extension MemoryObserver {

    enum MemoryError: Error {

        case failure(String)
    }
}
