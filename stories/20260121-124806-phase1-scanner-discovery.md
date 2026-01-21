# Phase 1: Scanner Discovery and Basic Scanning

**Date:** 2026-01-21
**Branch:** `phase1-scanner-discovery`

## Overview

This phase implements scanner discovery and image capture with memory-based transfer. The deliverables are:

- ScannerManager class with device discovery
- Scanner session management
- Functional unit selection and configuration
- Band assembly into CGImage
- Basic CLI with `list` command and `scan` command (outputs PNG for testing)

## Detailed Design

### Protocol Abstractions

To enable unit testing without physical scanner hardware, we define protocols that mirror the ImageCaptureCore classes:

```swift
protocol DeviceBrowserProtocol: AnyObject {
    var delegate: DeviceBrowserDelegateProtocol? { get set }
    var devices: [DeviceProtocol] { get }
    func start()
    func stop()
}

protocol DeviceBrowserDelegateProtocol: AnyObject {
    func deviceBrowser(_ browser: DeviceBrowserProtocol, didAdd device: DeviceProtocol, moreComing: Bool)
    func deviceBrowser(_ browser: DeviceBrowserProtocol, didRemove device: DeviceProtocol, moreGoing: Bool)
}

protocol DeviceProtocol: AnyObject {
    var name: String { get }
    var type: ICDeviceType { get }
}

protocol ScannerDeviceProtocol: DeviceProtocol {
    var delegate: ScannerDeviceDelegateProtocol? { get set }
    var availableFunctionalUnitTypes: [NSNumber] { get }
    var selectedFunctionalUnit: FunctionalUnitProtocol? { get }
    var transferMode: ICScannerTransferMode { get set }

    func requestOpenSession()
    func requestCloseSession()
    func requestSelectFunctionalUnit(_ type: ICScannerFunctionalUnitType)
    func requestScan()
    func cancelScan()
}

protocol ScannerDeviceDelegateProtocol: AnyObject {
    func deviceDidBecomeReady(_ device: DeviceProtocol)
    func device(_ device: DeviceProtocol, didOpenSessionWithError error: Error?)
    func device(_ device: DeviceProtocol, didCloseSessionWithError error: Error?)
    func scannerDevice(_ device: ScannerDeviceProtocol, didSelectFunctionalUnit unit: FunctionalUnitProtocol, error: Error?)
    func scannerDevice(_ device: ScannerDeviceProtocol, didScanToBandData data: BandDataProtocol)
    func scannerDevice(_ device: ScannerDeviceProtocol, didCompleteScanWithError error: Error?)
    func scannerDeviceDidBecomeAvailable(_ device: ScannerDeviceProtocol)
}

protocol FunctionalUnitProtocol: AnyObject {
    var type: ICScannerFunctionalUnitType { get }
    var supportedResolutions: IndexSet { get }
    var preferredResolutions: IndexSet { get }
    var resolution: Int { get set }
    var supportedBitDepths: IndexSet { get }
    var bitDepth: ICScannerBitDepth { get set }
    var pixelDataType: ICScannerPixelDataType { get set }
    var supportedDocumentTypes: IndexSet { get }
    var documentType: ICScannerDocumentType { get set }
    var physicalSize: NSSize { get }
    var scanArea: NSRect { get set }
}

protocol DocumentFeederUnitProtocol: FunctionalUnitProtocol {
    var supportsDuplexScanning: Bool { get }
    var duplexScanningEnabled: Bool { get set }
    var documentLoaded: Bool { get }
}

protocol BandDataProtocol {
    var fullImageWidth: Int { get }
    var fullImageHeight: Int { get }
    var bitsPerPixel: Int { get }
    var bitsPerComponent: Int { get }
    var bytesPerRow: Int { get }
    var dataStartRow: Int { get }
    var dataNumRows: Int { get }
    var dataBuffer: Data { get }
}
```

### Wrapper Classes

Thin wrappers around ImageCaptureCore classes that conform to our protocols:

- `ICDeviceBrowserWrapper: DeviceBrowserProtocol`
- `ICScannerDeviceWrapper: ScannerDeviceProtocol`
- `ICScannerFunctionalUnitWrapper: FunctionalUnitProtocol`
- `ICScannerBandDataWrapper: BandDataProtocol`

### ScannerManager

The main class orchestrating scanner operations:

```swift
class ScannerManager {
    private let browser: DeviceBrowserProtocol
    private var scanners: [ScannerDeviceProtocol] = []
    private var continuation: AsyncStream<CGImage>.Continuation?
    private var bandAssembler: BandAssembler?

    init(browser: DeviceBrowserProtocol = ICDeviceBrowserWrapper())

    // Discovery
    func discoverScanners(timeout: TimeInterval = 2.0) async -> [ScannerDeviceProtocol]

    // Scanning
    func scan(
        device: ScannerDeviceProtocol,
        config: ScanConfiguration
    ) -> AsyncStream<CGImage>
}
```

### ScanConfiguration

Value type holding scan parameters:

```swift
struct ScanConfiguration {
    var functionalUnitType: ICScannerFunctionalUnitType = .documentFeeder
    var resolution: Int = 300
    var colorMode: ColorMode = .color
    var pageSize: PageSize = .letter
    var duplex: Bool = false

    enum ColorMode {
        case color      // RGB, 8-bit
        case grayscale  // Gray, 8-bit
        case mono       // BW, 1-bit
    }

    enum PageSize {
        case letter     // 8.5" x 11"
        case legal      // 8.5" x 14"
        case a4         // 210mm x 297mm

        var documentType: ICScannerDocumentType { ... }
    }
}
```

### BandAssembler

Assembles scan bands into a complete CGImage:

```swift
class BandAssembler {
    private var buffer: UnsafeMutableRawPointer?
    private var width: Int = 0
    private var height: Int = 0
    private var bytesPerRow: Int = 0
    private var bitsPerComponent: Int = 0
    private var bitsPerPixel: Int = 0

    func receiveBand(_ data: BandDataProtocol)
    func assembleImage() -> CGImage?
    func reset()
}
```

The assembler:
1. On first band, allocates buffer based on `fullImageWidth`, `fullImageHeight`, and pixel format
2. For each band, copies `dataBuffer` to `buffer + (dataStartRow * bytesPerRow)`
3. On `assembleImage()`, creates CGImage from buffer with correct color space and bitmap info

### CLI Structure

Using Swift Argument Parser:

```swift
@main
struct DocboxCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "docbox",
        abstract: "Scan documents to searchable PDFs",
        subcommands: [ListCommand.self, ScanCommand.self]
    )
}

struct ListCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available scanners"
    )

    func run() async throws { ... }
}

struct ScanCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan documents"
    )

    @Option(name: .long, help: "Scanner name (partial match)")
    var scanner: String?

    @Flag(name: .long, help: "Use flatbed instead of document feeder")
    var flatbed: Bool = false

    @Flag(name: .long, help: "Enable duplex scanning")
    var duplex: Bool = false

    @Option(name: .long, help: "Resolution in DPI")
    var resolution: Int = 300

    @Flag(name: .long, help: "Scan in color")
    var color: Bool = false

    @Flag(name: .long, help: "Scan in grayscale")
    var grayscale: Bool = false

    @Flag(name: .long, help: "Scan in black and white")
    var mono: Bool = false

    @Option(name: .long, help: "Page size: letter, legal, a4")
    var pageSize: String = "letter"

    @Argument(help: "Output file path")
    var output: String

    func run() async throws { ... }
}
```

### Error Types

```swift
enum ScannerError: Error, LocalizedError {
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

    var errorDescription: String? { ... }
}
```

## Tasks

### Unit Tests

#### 1. BandAssembler Tests
- [ ] 1.1 Test single band assembly (entire image in one band)
- [ ] 1.2 Test multi-band assembly (image split into multiple bands)
- [ ] 1.3 Test RGB 8-bit pixel format
- [ ] 1.4 Test grayscale 8-bit pixel format
- [ ] 1.5 Test monochrome 1-bit pixel format
- [ ] 1.6 Test reset clears buffer and allows reuse
- [ ] 1.7 Test assembleImage returns nil before any bands received

#### 2. ScanConfiguration Tests
- [ ] 2.1 Test default configuration values
- [ ] 2.2 Test ColorMode to ICScannerPixelDataType/bitDepth conversion
- [ ] 2.3 Test PageSize to ICScannerDocumentType conversion
- [ ] 2.4 Test PageSize dimensions in inches

#### 3. ScannerManager Discovery Tests (with mocks)
- [ ] 3.1 Test discoverScanners returns empty array when no scanners
- [ ] 3.2 Test discoverScanners returns scanners found during timeout
- [ ] 3.3 Test scanner removal updates list
- [ ] 3.4 Test only scanner devices are included (not cameras)

#### 4. ScannerManager Session Tests (with mocks)
- [x] 4.1 Test successful session open
- [x] 4.2 Test session open failure (device busy)
- [x] 4.3 Test session close after scan completes
- [x] 4.4 Test session close on error

#### 4b. ScannerManager Device Ready Flow Tests (discovered during implementation)
- [x] 4b.1 Test scan waits for deviceDidBecomeReady before selecting functional unit
- [x] 4b.2 Test functional units empty before device ready
- [x] 4b.3 Test scan completes successfully with realistic callback flow
- [x] 4b.4 Test scanSinglePage completes successfully with realistic callback flow
- [x] 4b.5 Test scan timeout when device never becomes ready

#### 4c. ScannerManager Scanner Availability Tests (discovered during implementation)
- [x] 4c.1 Test scanner becomes available after another client releases it

#### 4d. ScannerManager Browser Lifecycle Tests (discovered during implementation)
- [x] 4d.1 Test browser stays running during scan for valid device handles
- [x] 4d.2 Test discovery followed by immediate scan succeeds

#### 5. ScannerManager Configuration Tests (with mocks)
- [ ] 5.1 Test functional unit selection (flatbed vs feeder)
- [ ] 5.2 Test resolution validation against supported resolutions
- [ ] 5.3 Test color mode configuration
- [ ] 5.4 Test page size configuration
- [ ] 5.5 Test duplex configuration when supported
- [ ] 5.6 Test duplex configuration rejected when not supported

#### 6. ScannerManager Scanning Tests (with mocks)
- [ ] 6.1 Test single page scan produces one CGImage
- [ ] 6.2 Test multi-page scan produces multiple CGImages
- [ ] 6.3 Test scan error propagates through AsyncStream
- [ ] 6.4 Test scan cancellation

#### 7. CLI Argument Parsing Tests
- [ ] 7.1 Test list command parsing
- [ ] 7.2 Test scan command with all options
- [ ] 7.3 Test scan command with defaults
- [ ] 7.4 Test mutually exclusive color options error
- [ ] 7.5 Test invalid page size error
- [ ] 7.6 Test missing output argument error

### Integration Tests

#### 8. Mock Scanner Integration Tests
- [ ] 8.1 Test full scan flow with mock scanner returning test image bands
- [ ] 8.2 Test multi-page scan produces correct number of images
- [ ] 8.3 Test scan configuration is correctly applied to mock scanner

#### 9. CLI Integration Tests
- [ ] 9.1 Test list command output format
- [ ] 9.2 Test scan command writes PNG file
- [ ] 9.3 Test scan command error messages

### Implementation

#### 10. Core Types
- [ ] 10.1 Implement protocol definitions
- [ ] 10.2 Implement ScanConfiguration
- [ ] 10.3 Implement ScannerError

#### 11. BandAssembler
- [ ] 11.1 Implement buffer allocation on first band
- [ ] 11.2 Implement band data copying
- [ ] 11.3 Implement CGImage construction
- [ ] 11.4 Implement reset functionality

#### 12. ImageCaptureCore Wrappers
- [ ] 12.1 Implement ICDeviceBrowserWrapper
- [ ] 12.2 Implement ICScannerDeviceWrapper
- [ ] 12.3 Implement ICScannerFunctionalUnitWrapper
- [ ] 12.4 Implement ICScannerBandDataWrapper

#### 13. ScannerManager
- [ ] 13.1 Implement device browser delegate
- [ ] 13.2 Implement discoverScanners with timeout
- [ ] 13.3 Implement session management
- [ ] 13.4 Implement functional unit configuration
- [ ] 13.5 Implement scan with AsyncStream
- [ ] 13.6 Implement scanner delegate for band reception

#### 14. CLI
- [ ] 14.1 Add Swift Argument Parser dependency
- [ ] 14.2 Implement DocboxCommand structure
- [ ] 14.3 Implement ListCommand
- [ ] 14.4 Implement ScanCommand
- [ ] 14.5 Implement PNG output for testing

#### 15. Project Configuration
- [ ] 15.1 Add test target to Xcode project
- [ ] 15.2 Add Swift Argument Parser package dependency
- [ ] 15.3 Configure entitlements for scanner access
