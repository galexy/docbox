import Foundation
import ImageCaptureCore
@testable import DocboxKit

// MARK: - Mock Device Browser

final class MockDeviceBrowser: DeviceBrowserProtocol {
    weak var delegate: (any DeviceBrowserDelegateProtocol)?
    private(set) var isStarted = false
    private var _devices: [any DeviceProtocol] = []

    var devices: [any DeviceProtocol] {
        return _devices
    }

    func start() {
        isStarted = true
    }

    func stop() {
        isStarted = false
    }

    // Test helpers
    func simulateDeviceFound(_ device: any DeviceProtocol, moreComing: Bool = false) {
        _devices.append(device)
        delegate?.deviceBrowser(self, didAdd: device, moreComing: moreComing)
    }

    func simulateDeviceRemoved(_ device: any DeviceProtocol, moreGoing: Bool = false) {
        _devices.removeAll { ($0 as AnyObject) === (device as AnyObject) }
        delegate?.deviceBrowser(self, didRemove: device, moreGoing: moreGoing)
    }
}

// MARK: - Mock Device

class MockDevice: DeviceProtocol {
    let name: String
    let deviceType: ICDeviceType

    init(name: String, deviceType: ICDeviceType = .scanner) {
        self.name = name
        self.deviceType = deviceType
    }
}

// MARK: - Mock Scanner Device

final class MockScannerDevice: MockDevice, ScannerDeviceProtocol {
    weak var scannerDelegate: (any ScannerDeviceDelegateProtocol)?

    // Functional units - empty until device becomes ready (simulates real behavior)
    private var _availableFunctionalUnitTypes: [NSNumber] = []
    var availableFunctionalUnitTypes: [NSNumber] {
        return isDeviceReady ? _functionalUnitTypesAfterReady : []
    }

    // What functional units will be available after device is ready
    var _functionalUnitTypesAfterReady: [NSNumber] = [
        NSNumber(value: ICScannerFunctionalUnitType.flatbed.rawValue),
        NSNumber(value: ICScannerFunctionalUnitType.documentFeeder.rawValue)
    ]

    var selectedFunctionalUnit: (any FunctionalUnitProtocol)?
    var transferMode: ICScannerTransferMode = .memoryBased

    // State tracking for tests
    private(set) var isSessionOpen = false
    private(set) var isDeviceReady = false
    private(set) var lastRequestedFunctionalUnitType: ICScannerFunctionalUnitType?
    private(set) var scanRequested = false
    private(set) var scanCancelled = false

    // Configuration for mock behavior
    var sessionOpenError: Error?
    var sessionCloseError: Error?
    var functionalUnitSelectionError: Error?
    var scanError: Error?
    var bandsToDeliver: [[any BandDataProtocol]] = []  // Array of pages, each page is array of bands
    var shouldSimulateNoPages = false

    // Control realistic timing behavior
    var simulateRealisticCallbacks = false  // When true, simulates real device callback sequence
    var deviceReadyDelay: TimeInterval = 0.05  // Delay before deviceDidBecomeReady
    var skipDeviceReady = false  // For testing timeout when device never becomes ready

    init(name: String = "Mock Scanner") {
        super.init(name: name, deviceType: .scanner)
    }

    func requestOpenSession() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let error = self.sessionOpenError {
                self.scannerDelegate?.device(self, didOpenSessionWithError: error)
            } else {
                self.isSessionOpen = true
                self.scannerDelegate?.device(self, didOpenSessionWithError: nil)

                // Simulate realistic behavior: deviceDidBecomeReady comes after session opens
                if self.simulateRealisticCallbacks && !self.skipDeviceReady {
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.deviceReadyDelay) { [weak self] in
                        guard let self = self else { return }
                        self.isDeviceReady = true
                        self.scannerDelegate?.deviceDidBecomeReady(self)
                    }
                } else if !self.simulateRealisticCallbacks {
                    // Legacy behavior: immediately ready for backward compatibility
                    self.isDeviceReady = true
                    self.scannerDelegate?.deviceDidBecomeReady(self)
                }
            }
        }
    }

    func requestCloseSession() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSessionOpen = false
            self.isDeviceReady = false
            self.scannerDelegate?.device(self, didCloseSessionWithError: self.sessionCloseError)
        }
    }

    // Test helper: simulate scanner becoming available (another client released it)
    func simulateScannerBecameAvailable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scannerDelegate?.scannerDeviceDidBecomeAvailable(self)
        }
    }

    func requestSelectFunctionalUnit(_ type: ICScannerFunctionalUnitType) {
        lastRequestedFunctionalUnitType = type
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let error = self.functionalUnitSelectionError {
                self.scannerDelegate?.scannerDevice(self, didSelectFunctionalUnit: MockFunctionalUnit(type: type), error: error)
            } else {
                let unit: any FunctionalUnitProtocol
                if type == .documentFeeder {
                    unit = MockDocumentFeederUnit()
                } else {
                    unit = MockFunctionalUnit(type: type)
                }
                self.selectedFunctionalUnit = unit
                self.scannerDelegate?.scannerDevice(self, didSelectFunctionalUnit: unit, error: nil)
            }
        }
    }

    func requestScan() {
        scanRequested = true
        scanCancelled = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.shouldSimulateNoPages {
                let error = NSError(domain: "ICScannerError", code: -9923, userInfo: [NSLocalizedDescriptionKey: "No pages in feeder"])
                self.scannerDelegate?.scannerDevice(self, didCompleteScanWithError: error)
                return
            }

            if let error = self.scanError {
                self.scannerDelegate?.scannerDevice(self, didCompleteScanWithError: error)
                return
            }

            // Deliver bands for each page
            for pageBands in self.bandsToDeliver {
                for band in pageBands {
                    if self.scanCancelled { return }
                    self.scannerDelegate?.scannerDevice(self, didScanToBandData: band)
                }
            }

            self.scannerDelegate?.scannerDevice(self, didCompleteScanWithError: nil)
        }
    }

    func cancelScan() {
        scanCancelled = true
    }
}

// MARK: - Mock Functional Unit

class MockFunctionalUnit: FunctionalUnitProtocol {
    let type: ICScannerFunctionalUnitType
    var supportedResolutions: IndexSet = IndexSet([150, 300, 600, 1200])
    var preferredResolutions: IndexSet = IndexSet([300])
    var resolution: Int = 300
    var supportedBitDepths: IndexSet = IndexSet([1, 8])
    var bitDepth: ICScannerBitDepth = .depth8Bits
    var pixelDataType: ICScannerPixelDataType = .RGB
    var physicalSize: NSSize = NSSize(width: 8.5 * 72, height: 11 * 72)  // Letter size in points
    var scanArea: NSRect = NSRect(x: 0, y: 0, width: 8.5 * 72, height: 11 * 72)

    init(type: ICScannerFunctionalUnitType = .flatbed) {
        self.type = type
    }
}

// MARK: - Mock Document Feeder Unit

final class MockDocumentFeederUnit: MockFunctionalUnit, DocumentFeederUnitProtocol {
    var supportedDocumentTypes: IndexSet = IndexSet([
        Int(ICScannerDocumentType.typeUSLetter.rawValue),
        Int(ICScannerDocumentType.typeUSLegal.rawValue),
        Int(ICScannerDocumentType.typeA4.rawValue)
    ])
    var documentType: ICScannerDocumentType = .typeUSLetter
    var supportsDuplexScanning: Bool = true
    var duplexScanningEnabled: Bool = false
    var documentLoaded: Bool = true

    init() {
        super.init(type: .documentFeeder)
    }
}
