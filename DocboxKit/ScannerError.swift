import Foundation

/// Errors that can occur during scanner operations
public enum ScannerError: Error, LocalizedError {
    case noScannersFound
    case scannerNotFound(name: String)
    case scannerBusy
    case sessionFailed(Error?)
    case unsupportedResolution(requested: Int, available: IndexSet)
    case unsupportedColorMode
    case unsupportedPageSize
    case noPagesInFeeder
    case scanFailed(Error?)
    case imageAssemblyFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case .noScannersFound:
            return "No scanners found"
        case .scannerNotFound(let name):
            return "Scanner not found: \(name)"
        case .scannerBusy:
            return "Scanner is busy or in use by another application"
        case .sessionFailed(let error):
            if let error = error {
                return "Failed to open scanner session: \(error.localizedDescription)"
            }
            return "Failed to open scanner session"
        case .unsupportedResolution(let requested, let available):
            return "Resolution \(requested) DPI is not supported. Available: \(available)"
        case .unsupportedColorMode:
            return "The selected color mode is not supported by this scanner"
        case .unsupportedPageSize:
            return "The selected page size is not supported by this scanner"
        case .noPagesInFeeder:
            return "No pages in document feeder"
        case .scanFailed(let error):
            if let error = error {
                return "Scan failed: \(error.localizedDescription)"
            }
            return "Scan failed"
        case .imageAssemblyFailed:
            return "Failed to assemble scanned image from band data"
        case .timeout:
            return "Operation timed out"
        }
    }
}
