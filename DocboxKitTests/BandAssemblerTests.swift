import Testing
import Foundation
import CoreGraphics
@testable import DocboxKit

/// Mock band data for testing
struct MockBandData: BandDataProtocol {
    var fullImageWidth: Int
    var fullImageHeight: Int
    var bitsPerPixel: Int
    var bitsPerComponent: Int
    var bytesPerRow: Int
    var dataStartRow: Int
    var dataNumRows: Int
    var dataBuffer: Data?

    /// Create mock band data with a solid color
    static func solidColor(
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        bitsPerComponent: Int,
        startRow: Int,
        numRows: Int,
        colorValue: UInt8
    ) -> MockBandData {
        let bytesPerRow = (width * bitsPerPixel + 7) / 8
        let bandSize = numRows * bytesPerRow
        let data = Data(repeating: colorValue, count: bandSize)

        return MockBandData(
            fullImageWidth: width,
            fullImageHeight: height,
            bitsPerPixel: bitsPerPixel,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            dataStartRow: startRow,
            dataNumRows: numRows,
            dataBuffer: data
        )
    }
}

@Suite("BandAssembler Tests")
struct BandAssemblerTests {

    // MARK: - Task 1.1: Single band assembly

    @Test("Single band assembly - entire image in one band")
    func singleBandAssembly() {
        let assembler = BandAssembler()
        let width = 100
        let height = 50

        // Create a single band containing the entire image (grayscale)
        let band = MockBandData.solidColor(
            width: width,
            height: height,
            bitsPerPixel: 8,
            bitsPerComponent: 8,
            startRow: 0,
            numRows: height,
            colorValue: 128
        )

        assembler.receiveBand(band)
        let image = assembler.assembleImage()

        #expect(image != nil)
        #expect(image?.width == width)
        #expect(image?.height == height)
    }

    // MARK: - Task 1.2: Multi-band assembly

    @Test("Multi-band assembly - image split into multiple bands")
    func multiBandAssembly() {
        let assembler = BandAssembler()
        let width = 100
        let height = 60
        let bandsCount = 3
        let rowsPerBand = height / bandsCount

        // Send bands in order
        for i in 0..<bandsCount {
            let band = MockBandData.solidColor(
                width: width,
                height: height,
                bitsPerPixel: 8,
                bitsPerComponent: 8,
                startRow: i * rowsPerBand,
                numRows: rowsPerBand,
                colorValue: UInt8(i * 80)
            )
            assembler.receiveBand(band)
        }

        let image = assembler.assembleImage()

        #expect(image != nil)
        #expect(image?.width == width)
        #expect(image?.height == height)
    }

    // MARK: - Task 1.3: RGB 8-bit pixel format

    @Test("RGB 8-bit pixel format assembly")
    func rgbAssembly() {
        let assembler = BandAssembler()
        let width = 50
        let height = 30

        let band = MockBandData.solidColor(
            width: width,
            height: height,
            bitsPerPixel: 24,  // RGB = 3 bytes = 24 bits
            bitsPerComponent: 8,
            startRow: 0,
            numRows: height,
            colorValue: 200
        )

        assembler.receiveBand(band)
        let image = assembler.assembleImage()

        #expect(image != nil)
        #expect(image?.width == width)
        #expect(image?.height == height)
        #expect(image?.bitsPerPixel == 24)
        #expect(image?.bitsPerComponent == 8)
    }

    // MARK: - Task 1.4: Grayscale 8-bit pixel format

    @Test("Grayscale 8-bit pixel format assembly")
    func grayscaleAssembly() {
        let assembler = BandAssembler()
        let width = 50
        let height = 30

        let band = MockBandData.solidColor(
            width: width,
            height: height,
            bitsPerPixel: 8,
            bitsPerComponent: 8,
            startRow: 0,
            numRows: height,
            colorValue: 128
        )

        assembler.receiveBand(band)
        let image = assembler.assembleImage()

        #expect(image != nil)
        #expect(image?.width == width)
        #expect(image?.height == height)
        #expect(image?.bitsPerPixel == 8)
        #expect(image?.bitsPerComponent == 8)
    }

    // MARK: - Task 1.5: Monochrome 1-bit pixel format

    @Test("Monochrome 1-bit pixel format assembly")
    func monochromeAssembly() {
        let assembler = BandAssembler()
        let width = 80  // Multiple of 8 for easy byte alignment
        let height = 30

        let band = MockBandData.solidColor(
            width: width,
            height: height,
            bitsPerPixel: 1,
            bitsPerComponent: 1,
            startRow: 0,
            numRows: height,
            colorValue: 0xFF  // All white
        )

        assembler.receiveBand(band)
        let image = assembler.assembleImage()

        #expect(image != nil)
        #expect(image?.width == width)
        #expect(image?.height == height)
    }

    // MARK: - Task 1.6: Reset clears buffer

    @Test("Reset clears buffer and allows reuse")
    func resetClearsBuffer() {
        let assembler = BandAssembler()

        // First image
        let band1 = MockBandData.solidColor(
            width: 50,
            height: 30,
            bitsPerPixel: 8,
            bitsPerComponent: 8,
            startRow: 0,
            numRows: 30,
            colorValue: 100
        )
        assembler.receiveBand(band1)
        let image1 = assembler.assembleImage()
        #expect(image1 != nil)
        #expect(image1?.width == 50)

        // Reset
        assembler.reset()

        // Second image with different dimensions
        let band2 = MockBandData.solidColor(
            width: 80,
            height: 40,
            bitsPerPixel: 8,
            bitsPerComponent: 8,
            startRow: 0,
            numRows: 40,
            colorValue: 200
        )
        assembler.receiveBand(band2)
        let image2 = assembler.assembleImage()

        #expect(image2 != nil)
        #expect(image2?.width == 80)
        #expect(image2?.height == 40)
    }

    // MARK: - Task 1.7: assembleImage returns nil before bands received

    @Test("assembleImage returns nil before any bands received")
    func assembleImageReturnsNilBeforeBands() {
        let assembler = BandAssembler()
        let image = assembler.assembleImage()
        #expect(image == nil)
    }
}
