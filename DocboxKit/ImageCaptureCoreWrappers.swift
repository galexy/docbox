import Foundation
import ImageCaptureCore

// MARK: - Device Browser Wrapper

/// Wrapper around ICDeviceBrowser that conforms to DeviceBrowserProtocol
public final class ICDeviceBrowserWrapper: NSObject, DeviceBrowserProtocol {
    private let browser: ICDeviceBrowser
    private var deviceWrappers: [String: ICDeviceWrapper] = [:]

    public weak var delegate: (any DeviceBrowserDelegateProtocol)?

    public var devices: [any DeviceProtocol] {
        return Array(deviceWrappers.values)
    }

    public override init() {
        browser = ICDeviceBrowser()
        super.init()
        browser.delegate = self
        // Browse for scanners - combine device type with location types
        // Need to use rawValue OR to combine ICDeviceTypeMask with ICDeviceLocationTypeMask
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue:
            ICDeviceTypeMask.scanner.rawValue |
            ICDeviceLocationTypeMask.local.rawValue |      // USB
            ICDeviceLocationTypeMask.shared.rawValue |     // Shared
            ICDeviceLocationTypeMask.bonjour.rawValue      // Network
        )!
    }

    public func start() {
        browser.start()
    }

    public func stop() {
        browser.stop()
    }
}

extension ICDeviceBrowserWrapper: ICDeviceBrowserDelegate {
    public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        let wrapper: ICDeviceWrapper
        if let scanner = device as? ICScannerDevice {
            wrapper = ICScannerDeviceWrapper(device: scanner)
        } else {
            wrapper = ICDeviceWrapper(device: device)
        }
        deviceWrappers[device.uuidString ?? UUID().uuidString] = wrapper
        delegate?.deviceBrowser(self, didAdd: wrapper, moreComing: moreComing)
    }

    public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        if let uuid = device.uuidString, let wrapper = deviceWrappers.removeValue(forKey: uuid) {
            delegate?.deviceBrowser(self, didRemove: wrapper, moreGoing: moreGoing)
        }
    }
}

// MARK: - Device Wrapper

/// Wrapper around ICDevice that conforms to DeviceProtocol
class ICDeviceWrapper: DeviceProtocol {
    let device: ICDevice

    var name: String {
        return device.name ?? "Unknown"
    }

    var deviceType: ICDeviceType {
        return device.type
    }

    init(device: ICDevice) {
        self.device = device
    }
}

// MARK: - Scanner Device Wrapper

/// Wrapper around ICScannerDevice that conforms to ScannerDeviceProtocol
final class ICScannerDeviceWrapper: ICDeviceWrapper, ScannerDeviceProtocol {
    private var scannerDevice: ICScannerDevice {
        return device as! ICScannerDevice
    }

    private let delegateAdapter = ScannerDelegateAdapter()

    weak var scannerDelegate: (any ScannerDeviceDelegateProtocol)? {
        get { delegateAdapter.delegate }
        set {
            delegateAdapter.delegate = newValue
            delegateAdapter.wrapper = self
        }
    }

    var availableFunctionalUnitTypes: [NSNumber] {
        return scannerDevice.availableFunctionalUnitTypes
    }

    var selectedFunctionalUnit: (any FunctionalUnitProtocol)? {
        let unit = scannerDevice.selectedFunctionalUnit
        if let feeder = unit as? ICScannerFunctionalUnitDocumentFeeder {
            return ICScannerFunctionalUnitDocumentFeederWrapper(unit: feeder)
        }
        return ICScannerFunctionalUnitWrapper(unit: unit)
    }

    var transferMode: ICScannerTransferMode {
        get { scannerDevice.transferMode }
        set { scannerDevice.transferMode = newValue }
    }

    init(device: ICScannerDevice) {
        super.init(device: device)
        device.delegate = delegateAdapter
    }

    func requestOpenSession() {
        scannerDevice.requestOpenSession()
    }

    func requestCloseSession() {
        scannerDevice.requestCloseSession()
    }

    func requestSelectFunctionalUnit(_ type: ICScannerFunctionalUnitType) {
        scannerDevice.requestSelect(type)
    }

    func requestScan() {
        scannerDevice.requestScan()
    }

    func cancelScan() {
        scannerDevice.cancelScan()
    }
}

// MARK: - Scanner Delegate Adapter

/// Adapter to bridge ICScannerDeviceDelegate to ScannerDeviceDelegateProtocol
private final class ScannerDelegateAdapter: NSObject, ICDeviceDelegate, ICScannerDeviceDelegate {
    weak var delegate: (any ScannerDeviceDelegateProtocol)?
    weak var wrapper: ICScannerDeviceWrapper?

    func deviceDidBecomeReady(_ device: ICDevice) {
        guard let wrapper = wrapper else { return }
        delegate?.deviceDidBecomeReady(wrapper)
    }

    func device(_ device: ICDevice, didOpenSessionWithError error: (any Error)?) {
        guard let wrapper = wrapper else { return }
        delegate?.device(wrapper, didOpenSessionWithError: error)
    }

    func device(_ device: ICDevice, didCloseSessionWithError error: (any Error)?) {
        guard let wrapper = wrapper else { return }
        delegate?.device(wrapper, didCloseSessionWithError: error)
    }

    func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: (any Error)?) {
        guard let wrapper = wrapper else { return }
        let unitWrapper: any FunctionalUnitProtocol
        if let feeder = functionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            unitWrapper = ICScannerFunctionalUnitDocumentFeederWrapper(unit: feeder)
        } else {
            unitWrapper = ICScannerFunctionalUnitWrapper(unit: functionalUnit)
        }
        delegate?.scannerDevice(wrapper, didSelectFunctionalUnit: unitWrapper, error: error)
    }

    func scannerDevice(_ scanner: ICScannerDevice, didScanTo data: ICScannerBandData) {
        guard let wrapper = wrapper else { return }
        delegate?.scannerDevice(wrapper, didScanToBandData: data)
    }

    func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: (any Error)?) {
        guard let wrapper = wrapper else { return }
        delegate?.scannerDevice(wrapper, didCompleteScanWithError: error)
    }

    func scannerDeviceDidBecomeAvailable(_ scanner: ICScannerDevice) {
        guard let wrapper = wrapper else { return }
        delegate?.scannerDeviceDidBecomeAvailable(wrapper)
    }

    func didRemove(_ device: ICDevice) {
        // Handle device removal if needed
    }
}

// MARK: - Functional Unit Wrapper

/// Wrapper around ICScannerFunctionalUnit that conforms to FunctionalUnitProtocol
class ICScannerFunctionalUnitWrapper: FunctionalUnitProtocol {
    let unit: ICScannerFunctionalUnit

    var type: ICScannerFunctionalUnitType {
        return unit.type
    }

    var supportedResolutions: IndexSet {
        return unit.supportedResolutions
    }

    var preferredResolutions: IndexSet {
        return unit.preferredResolutions
    }

    var resolution: Int {
        get { unit.resolution }
        set { unit.resolution = newValue }
    }

    var supportedBitDepths: IndexSet {
        return unit.supportedBitDepths
    }

    var bitDepth: ICScannerBitDepth {
        get { unit.bitDepth }
        set { unit.bitDepth = newValue }
    }

    var pixelDataType: ICScannerPixelDataType {
        get { unit.pixelDataType }
        set { unit.pixelDataType = newValue }
    }

    var physicalSize: NSSize {
        return unit.physicalSize
    }

    var scanArea: NSRect {
        get { unit.scanArea }
        set { unit.scanArea = newValue }
    }

    init(unit: ICScannerFunctionalUnit) {
        self.unit = unit
    }
}

// MARK: - Document Feeder Wrapper

/// Wrapper around ICScannerFunctionalUnitDocumentFeeder
final class ICScannerFunctionalUnitDocumentFeederWrapper: ICScannerFunctionalUnitWrapper, DocumentFeederUnitProtocol {
    private var feederUnit: ICScannerFunctionalUnitDocumentFeeder {
        return unit as! ICScannerFunctionalUnitDocumentFeeder
    }

    var supportedDocumentTypes: IndexSet {
        return feederUnit.supportedDocumentTypes
    }

    var documentType: ICScannerDocumentType {
        get { feederUnit.documentType }
        set { feederUnit.documentType = newValue }
    }

    var supportsDuplexScanning: Bool {
        return feederUnit.supportsDuplexScanning
    }

    var duplexScanningEnabled: Bool {
        get { feederUnit.duplexScanningEnabled }
        set { feederUnit.duplexScanningEnabled = newValue }
    }

    var documentLoaded: Bool {
        return feederUnit.documentLoaded
    }

    init(unit: ICScannerFunctionalUnitDocumentFeeder) {
        super.init(unit: unit)
    }
}
