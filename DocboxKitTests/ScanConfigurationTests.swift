import Testing
import ImageCaptureCore
@testable import DocboxKit

@Suite("ScanConfiguration Tests")
struct ScanConfigurationTests {

    // MARK: - Task 2.1: Default configuration values

    @Test("Default configuration has expected values")
    func defaultConfiguration() {
        let config = ScanConfiguration()

        #expect(config.functionalUnitType == .documentFeeder)
        #expect(config.resolution == 300)
        #expect(config.colorMode == .color)
        #expect(config.pageSize == .letter)
        #expect(config.duplex == false)
    }

    // MARK: - Task 2.2: ColorMode to ICScannerPixelDataType/bitDepth conversion

    @Test("ColorMode.color converts to RGB pixel data type")
    func colorModeColorConversion() {
        let colorMode = ScanConfiguration.ColorMode.color

        #expect(colorMode.pixelDataType == .RGB)
        #expect(colorMode.bitDepth == .depth8Bits)
    }

    @Test("ColorMode.grayscale converts to gray pixel data type")
    func colorModeGrayscaleConversion() {
        let colorMode = ScanConfiguration.ColorMode.grayscale

        #expect(colorMode.pixelDataType == .gray)
        #expect(colorMode.bitDepth == .depth8Bits)
    }

    @Test("ColorMode.mono converts to BW pixel data type with 1-bit depth")
    func colorModeMonoConversion() {
        let colorMode = ScanConfiguration.ColorMode.mono

        #expect(colorMode.pixelDataType == .BW)
        #expect(colorMode.bitDepth == .depth1Bit)
    }

    // MARK: - Task 2.3: PageSize to ICScannerDocumentType conversion

    @Test("PageSize.letter converts to USLetter document type")
    func pageSizeLetterConversion() {
        let pageSize = ScanConfiguration.PageSize.letter
        #expect(pageSize.documentType == .typeUSLetter)
    }

    @Test("PageSize.legal converts to USLegal document type")
    func pageSizeLegalConversion() {
        let pageSize = ScanConfiguration.PageSize.legal
        #expect(pageSize.documentType == .typeUSLegal)
    }

    @Test("PageSize.a4 converts to A4 document type")
    func pageSizeA4Conversion() {
        let pageSize = ScanConfiguration.PageSize.a4
        #expect(pageSize.documentType == .typeA4)
    }

    // MARK: - Task 2.4: PageSize dimensions in inches

    @Test("PageSize.letter has correct dimensions")
    func pageSizeLetterDimensions() {
        let pageSize = ScanConfiguration.PageSize.letter
        let dims = pageSize.dimensions

        #expect(dims.width == 8.5)
        #expect(dims.height == 11.0)
    }

    @Test("PageSize.legal has correct dimensions")
    func pageSizeLegalDimensions() {
        let pageSize = ScanConfiguration.PageSize.legal
        let dims = pageSize.dimensions

        #expect(dims.width == 8.5)
        #expect(dims.height == 14.0)
    }

    @Test("PageSize.a4 has correct dimensions")
    func pageSizeA4Dimensions() {
        let pageSize = ScanConfiguration.PageSize.a4
        let dims = pageSize.dimensions

        // A4 is 210mm x 297mm = 8.27" x 11.69"
        #expect(abs(dims.width - 8.27) < 0.01)
        #expect(abs(dims.height - 11.69) < 0.01)
    }

    // MARK: - All color modes enumerable

    @Test("All color modes are enumerable")
    func allColorModesCaseIterable() {
        let allCases = ScanConfiguration.ColorMode.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.color))
        #expect(allCases.contains(.grayscale))
        #expect(allCases.contains(.mono))
    }

    // MARK: - All page sizes enumerable

    @Test("All page sizes are enumerable")
    func allPageSizesCaseIterable() {
        let allCases = ScanConfiguration.PageSize.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.letter))
        #expect(allCases.contains(.legal))
        #expect(allCases.contains(.a4))
    }
}
