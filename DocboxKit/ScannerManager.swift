
import Foundation
import ImageCaptureCore
import CoreGraphics

/// Manages scanner discovery and scanning operations
public final class ScannerManager {
    private let browser: any DeviceBrowserProtocol
    private var scanners: [any ScannerDeviceProtocol] = []
    private var continuation: AsyncStream<CGImage>.Continuation?
    private var singlePageContinuation: CheckedContinuation<CGImage, Error>?
    private var bandAssembler: BandAssembler?
    private var currentScanner: (any ScannerDeviceProtocol)?
    private var currentConfig: ScanConfiguration?
    private var discoveryDelegate: DiscoveryDelegate?
    private var scanDelegate: ScanDelegate?

    /// Creates a ScannerManager with the default system device browser
    public convenience init() {
        self.init(browser: ICDeviceBrowserWrapper())
    }

    /// Creates a ScannerManager with the given device browser
    /// - Parameter browser: The device browser to use for discovery
    public init(browser: any DeviceBrowserProtocol) {
        self.browser = browser
    }

    // MARK: - Discovery

    /// Discovers available scanners within the specified timeout
    /// - Parameter timeout: Maximum time to wait for scanner discovery
    /// - Returns: Array of discovered scanner devices
    public func discoverScanners(timeout: TimeInterval = 2.0) async -> [any ScannerDeviceProtocol] {
        // Clear previous results
        scanners.removeAll()

        return await withCheckedContinuation { continuation in
            let delegate = DiscoveryDelegate(manager: self) { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                self.discoveryDelegate = nil
                continuation.resume(returning: self.scanners)
            }
            // Store delegate to keep it alive
            self.discoveryDelegate = delegate
            browser.delegate = delegate
            browser.start()

            // Schedule timeout - don't stop browser, just complete discovery
            // Keeping browser running allows device handles to remain valid
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                // Don't stop browser - self?.browser.stop()
                delegate.complete()
            }
        }
    }

    /// Returns the list of currently known scanners
    public var availableScanners: [any ScannerDeviceProtocol] {
        return scanners
    }

    // MARK: - Scanning

    /// Performs a scan with the given configuration
    /// - Parameters:
    ///   - device: The scanner device to use
    ///   - config: The scan configuration
    /// - Returns: An AsyncStream of scanned images
    /// Performs a scan and returns a single image
    /// - Parameters:
    ///   - device: The scanner device to use
    ///   - config: The scan configuration
    ///   - timeout: Maximum time to wait for the scan
    /// - Returns: The scanned image
    public func scanSinglePage(
        device: any ScannerDeviceProtocol,
        config: ScanConfiguration,
        timeout: TimeInterval = 30.0
    ) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.singlePageContinuation = continuation
            self.bandAssembler = BandAssembler()
            self.currentScanner = device
            self.currentConfig = config
            self.isWaitingForSession = true
            self.scanCompletedNormally = false

            // Set up scanner delegate and store to keep alive
            let delegate = ScanDelegate(manager: self)
            self.scanDelegate = delegate
            device.scannerDelegate = delegate

            // Open session immediately - callbacks will handle the rest
            device.requestOpenSession()

            // Set up timeout - fires if scan hasn't completed
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self = self else { return }
                // Timeout if we're still waiting for session, device ready, or have a pending continuation
                guard self.isWaitingForSession || self.isWaitingForDeviceReady || self.singlePageContinuation != nil else { return }
                self.singlePageContinuation?.resume(throwing: ScannerError.timeout)
                self.singlePageContinuation = nil
                self.currentScanner?.requestCloseSession()
                self.cleanup()
            }
        }
    }

    public func scan(
        device: any ScannerDeviceProtocol,
        config: ScanConfiguration,
        timeout: TimeInterval = 30.0
    ) -> AsyncStream<CGImage> {
        return AsyncStream { continuation in
            self.continuation = continuation
            self.bandAssembler = BandAssembler()
            self.currentScanner = device
            self.currentConfig = config
            self.isWaitingForSession = true
            self.scanCompletedNormally = false

            // Set up scanner delegate and store to keep alive
            let delegate = ScanDelegate(manager: self)
            self.scanDelegate = delegate
            device.scannerDelegate = delegate

            // Open session immediately - callbacks will handle the rest
            device.requestOpenSession()

            // Set up timeout - fires if scan hasn't completed
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self = self else { return }
                guard self.isWaitingForSession || self.isWaitingForDeviceReady || self.continuation != nil else { return }
                self.continuation?.finish()
                self.currentScanner?.requestCloseSession()
                self.cleanup()
            }

            continuation.onTermination = { [weak self, weak device] _ in
                guard let self = self else {
                    device?.requestCloseSession()
                    return
                }
                // Only cancel if scan didn't complete normally
                if !self.scanCompletedNormally {
                    device?.cancelScan()
                }
                device?.requestCloseSession()
                self.cleanup()
            }
        }
    }

    private var isWaitingForSession = false
    private var isWaitingForDeviceReady = false
    private var lastBandEndRow: Int = 0
    private var hasReceivedFirstBand = false
    private var scanCompletedNormally = false

    // MARK: - Internal

    func addScanner(_ device: any ScannerDeviceProtocol) {
        scanners.append(device)
    }

    func handleDeviceReady(device: any DeviceProtocol) {
        guard isWaitingForDeviceReady, let scanner = currentScanner else { return }
        isWaitingForDeviceReady = false

        // Now we can select the functional unit
        let unitType = currentConfig?.functionalUnitType ?? .documentFeeder
        scanner.requestSelectFunctionalUnit(unitType)
    }

    func handleScannerBecameAvailable(device: any ScannerDeviceProtocol) {
        // Another client released the scanner - try to open session again
        guard isWaitingForSession, let scanner = currentScanner else { return }
        scanner.requestOpenSession()
    }

    func removeScanner(_ device: any DeviceProtocol) {
        scanners.removeAll { ($0 as AnyObject) === (device as AnyObject) }
    }

    func handleSessionOpened(device: any DeviceProtocol, error: Error?) {
        guard currentScanner != nil else { return }

        if error != nil {
            // Don't give up - scannerDeviceDidBecomeAvailable will be called
            // when another client releases the scanner
            return
        }

        // Session opened - now wait for device to become ready
        isWaitingForSession = false
        isWaitingForDeviceReady = true
    }

    func handleSessionClosed(device: any DeviceProtocol, error: Error?) {
        cleanup()
    }

    func handleFunctionalUnitSelected(device: any ScannerDeviceProtocol, unit: any FunctionalUnitProtocol, error: Error?) {
        if let error = error {
            if let singleCont = singlePageContinuation {
                singleCont.resume(throwing: ScannerError.sessionFailed(error))
                singlePageContinuation = nil
            }
            continuation?.finish()
            device.requestCloseSession()
            return
        }

        // Configure the functional unit from ScanConfiguration
        if let config = currentConfig {

            // Set resolution if supported
            if unit.supportedResolutions.contains(config.resolution) {
                unit.resolution = config.resolution
            } else {
                // Fall back to a supported resolution
                if let fallback = unit.preferredResolutions.first ?? unit.supportedResolutions.first {
                    unit.resolution = fallback
                }
            }

            // Set color mode
            unit.pixelDataType = config.colorMode.pixelDataType
            unit.bitDepth = config.colorMode.bitDepth

            // Set scan area based on page size
            let dimensions = config.pageSize.dimensions
            let dpi = Double(unit.resolution)
            let scanWidth = dimensions.width * dpi
            let scanHeight = dimensions.height * dpi
            unit.scanArea = NSRect(x: 0, y: 0, width: scanWidth, height: scanHeight)

            // Configure document feeder specific settings
            if let feeder = unit as? DocumentFeederUnitProtocol {
                feeder.documentType = config.pageSize.documentType
                if feeder.supportsDuplexScanning {
                    feeder.duplexScanningEnabled = config.duplex
                }
            }
        }

        // Set transfer mode to memory-based
        device.transferMode = .memoryBased

        // Start scanning
        device.requestScan()
    }

    func handleBandData(_ data: any BandDataProtocol) {
        // Detect page boundary: if dataStartRow goes back to a lower value,
        // a new page has started. Yield the completed page first.
        if hasReceivedFirstBand && data.dataStartRow < lastBandEndRow {
            // New page detected - assemble and yield the previous page
            if let image = bandAssembler?.assembleImage() {
                if let singleCont = singlePageContinuation {
                    // For single page mode, return first page and ignore rest
                    singleCont.resume(returning: image)
                    singlePageContinuation = nil
                }
                continuation?.yield(image)
            }
            bandAssembler?.reset()
        }

        bandAssembler?.receiveBand(data)
        lastBandEndRow = data.dataStartRow + data.dataNumRows
        hasReceivedFirstBand = true
    }

    func handleScanComplete(device: any ScannerDeviceProtocol, error: Error?) {
        if let error = error {
            if let singleCont = singlePageContinuation {
                singleCont.resume(throwing: ScannerError.scanFailed(error))
                singlePageContinuation = nil
            }
            continuation?.finish()
            device.requestCloseSession()
            return
        }

        // Mark scan as completed normally - prevents cancelScan() in onTermination
        scanCompletedNormally = true

        // Assemble the final image
        if let image = bandAssembler?.assembleImage() {
            if let singleCont = singlePageContinuation {
                singleCont.resume(returning: image)
                singlePageContinuation = nil
            }
            continuation?.yield(image)
        } else {
            if let singleCont = singlePageContinuation {
                singleCont.resume(throwing: ScannerError.imageAssemblyFailed)
                singlePageContinuation = nil
            }
        }

        // Scan complete - finish stream (onTermination will close session)
        bandAssembler?.reset()
        continuation?.finish()
        // Note: requestCloseSession() is called by onTermination handler
        // to avoid race condition with cleanup()
    }

    private func cleanup() {
        bandAssembler = nil
        currentScanner = nil
        currentConfig = nil
        continuation = nil
        singlePageContinuation = nil
        scanDelegate = nil
        isWaitingForSession = false
        isWaitingForDeviceReady = false
        lastBandEndRow = 0
        hasReceivedFirstBand = false
        scanCompletedNormally = false
    }
}

// MARK: - Discovery Delegate

private final class DiscoveryDelegate: NSObject, DeviceBrowserDelegateProtocol {
    private weak var manager: ScannerManager?
    private var completionHandler: (() -> Void)?
    private var hasCompleted = false

    init(manager: ScannerManager, completion: @escaping () -> Void) {
        self.manager = manager
        self.completionHandler = completion
    }

    func complete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        completionHandler?()
    }

    func deviceBrowser(_ browser: any DeviceBrowserProtocol, didAdd device: any DeviceProtocol, moreComing: Bool) {
        // Only add scanner devices - check if scanner bit is set (deviceType includes location bits)
        let isScannerType = (device.deviceType.rawValue & ICDeviceType.scanner.rawValue) != 0
        if isScannerType, let scanner = device as? (any ScannerDeviceProtocol) {
            manager?.addScanner(scanner)
        }
    }

    func deviceBrowser(_ browser: any DeviceBrowserProtocol, didRemove device: any DeviceProtocol, moreGoing: Bool) {
        manager?.removeScanner(device)
    }
}

// MARK: - Scan Delegate

private final class ScanDelegate: NSObject, ScannerDeviceDelegateProtocol {
    private weak var manager: ScannerManager?

    init(manager: ScannerManager) {
        self.manager = manager
    }

    func deviceDidBecomeReady(_ device: any DeviceProtocol) {
        manager?.handleDeviceReady(device: device)
    }

    func device(_ device: any DeviceProtocol, didOpenSessionWithError error: Error?) {
        manager?.handleSessionOpened(device: device, error: error)
    }

    func device(_ device: any DeviceProtocol, didCloseSessionWithError error: Error?) {
        manager?.handleSessionClosed(device: device, error: error)
    }

    func scannerDevice(_ device: any ScannerDeviceProtocol, didSelectFunctionalUnit unit: any FunctionalUnitProtocol, error: Error?) {
        manager?.handleFunctionalUnitSelected(device: device, unit: unit, error: error)
    }

    func scannerDevice(_ device: any ScannerDeviceProtocol, didScanToBandData data: any BandDataProtocol) {
        manager?.handleBandData(data)
    }

    func scannerDevice(_ device: any ScannerDeviceProtocol, didCompleteScanWithError error: Error?) {
        manager?.handleScanComplete(device: device, error: error)
    }

    func scannerDeviceDidBecomeAvailable(_ device: any ScannerDeviceProtocol) {
        manager?.handleScannerBecameAvailable(device: device)
    }
}
