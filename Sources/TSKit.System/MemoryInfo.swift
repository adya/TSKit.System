import TSKit_Core

/// An object that represents memory size in bytes.
public typealias MemorySize = DataSize<UInt64>

/// An object that holds information about memory usage and availability.
public struct MemoryInfo {

    /// Amount of memory that is allocated and remains available for application.
    public let resident: MemorySize

    /// Peek amount of memory that was allocated and had been available for application.
    public let maxResident: MemorySize

    /// Amount of virtual memory available for the application.
    public let virtual: MemorySize

    /// Amount of physical memory available for the application.
    public let total: MemorySize

    /// Amount of physical memory that application is currently using.
    public let used: MemorySize

    /// Fraction of physical memory that application is currently using relative to total available memory.
    public var usedFraction: Double {
        return Double(used.totalBytes) / Double(total.totalBytes)
    }
}

// MARK: - CustomStringConvertible
extension MemoryInfo: CustomStringConvertible {

    public var description: String {
        return """
                Resident Memory: \(resident.maxDescription)
                Max Resident Memory: \(maxResident.maxDescription)
                Virtual Memory: \(virtual.maxDescription)
                Used VM Memory: \(used.maxDescription)
                Total Memory: \(total.maxDescription)
                U/T Ratio: \(usedFraction * 100.0)%
                """
    }
}
