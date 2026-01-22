import Foundation
import ImageCaptureCore

// MARK: - Device Browser Protocols

/// Protocol for device browser to enable testing
public protocol DeviceBrowserProtocol: AnyObject {
    var delegate: (any DeviceBrowserDelegateProtocol)? { get set }
    var devices: [any DeviceProtocol] { get }
    func start()
    func stop()
}

/// Protocol for device browser delegate
public protocol DeviceBrowserDelegateProtocol: AnyObject {
    func deviceBrowser(_ browser: any DeviceBrowserProtocol, didAdd device: any DeviceProtocol, moreComing: Bool)
    func deviceBrowser(_ browser: any DeviceBrowserProtocol, didRemove device: any DeviceProtocol, moreGoing: Bool)
}

// MARK: - Device Protocols

/// Protocol for generic device
public protocol DeviceProtocol: AnyObject {
    var name: String { get }
    var deviceType: ICDeviceType { get }
}

/// Protocol for scanner device
public protocol ScannerDeviceProtocol: DeviceProtocol {
    var scannerDelegate: (any ScannerDeviceDelegateProtocol)? { get set }
    var availableFunctionalUnitTypes: [NSNumber] { get }
    var selectedFunctionalUnit: (any FunctionalUnitProtocol)? { get }
    var transferMode: ICScannerTransferMode { get set }

    func requestOpenSession()
    func requestCloseSession()
    func requestSelectFunctionalUnit(_ type: ICScannerFunctionalUnitType)
    func requestScan()
    func cancelScan()
}

/// Protocol for scanner device delegate
public protocol ScannerDeviceDelegateProtocol: AnyObject {
    func deviceDidBecomeReady(_ device: any DeviceProtocol)
    func device(_ device: any DeviceProtocol, didOpenSessionWithError error: Error?)
    func device(_ device: any DeviceProtocol, didCloseSessionWithError error: Error?)
    func scannerDevice(_ device: any ScannerDeviceProtocol, didSelectFunctionalUnit unit: any FunctionalUnitProtocol, error: Error?)
    func scannerDevice(_ device: any ScannerDeviceProtocol, didScanToBandData data: any BandDataProtocol)
    func scannerDevice(_ device: any ScannerDeviceProtocol, didCompleteScanWithError error: Error?)
    /// Called when scanner becomes available (another client released it)
    func scannerDeviceDidBecomeAvailable(_ device: any ScannerDeviceProtocol)
}

// MARK: - Functional Unit Protocols

/// Protocol for scanner functional unit (base properties common to all units)
public protocol FunctionalUnitProtocol: AnyObject {
    var type: ICScannerFunctionalUnitType { get }
    var supportedResolutions: IndexSet { get }
    var preferredResolutions: IndexSet { get }
    var resolution: Int { get set }
    var supportedBitDepths: IndexSet { get }
    var bitDepth: ICScannerBitDepth { get set }
    var pixelDataType: ICScannerPixelDataType { get set }
    var physicalSize: NSSize { get }
    var scanArea: NSRect { get set }
}

/// Protocol for functional units that support document types (flatbed, document feeder)
public protocol DocumentTypeSupportingUnitProtocol: FunctionalUnitProtocol {
    var supportedDocumentTypes: IndexSet { get }
    var documentType: ICScannerDocumentType { get set }
}

/// Protocol for document feeder functional unit
public protocol DocumentFeederUnitProtocol: DocumentTypeSupportingUnitProtocol {
    var supportsDuplexScanning: Bool { get }
    var duplexScanningEnabled: Bool { get set }
    var documentLoaded: Bool { get }
}
