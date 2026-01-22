import Testing
import Foundation
import CoreGraphics
import PDFKit
@testable import DocboxKit

@Suite("PDFGenerator Tests")
struct PDFGeneratorTests {

    // MARK: - Helper

    /// Create a test image with specified dimensions
    private func createTestImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Failed to create test image context")
        }

        // Fill with a color
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()!
    }

    /// Create a temporary file URL for testing
    private func temporaryFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(UUID().uuidString + ".pdf")
    }

    // MARK: - Task 1.1: Single page PDF creation

    @Test("single page PDF creation")
    func singlePagePDFCreation() throws {
        let generator = PDFGenerator(resolution: 300)
        let image = createTestImage(width: 2550, height: 3300) // Letter at 300 DPI

        generator.addPage(image)
        #expect(generator.pageCount == 1)

        let url = temporaryFileURL()
        try generator.write(to: url)

        // Verify PDF was created
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Verify page count using PDFKit
        let document = PDFDocument(url: url)
        #expect(document != nil)
        #expect(document?.pageCount == 1)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 1.2: Multi-page PDF creation

    @Test("multi-page PDF creation")
    func multiPagePDFCreation() throws {
        let generator = PDFGenerator(resolution: 300)

        // Add 3 pages
        for _ in 0..<3 {
            let image = createTestImage(width: 2550, height: 3300)
            generator.addPage(image)
        }

        #expect(generator.pageCount == 3)

        let url = temporaryFileURL()
        try generator.write(to: url)

        // Verify PDF was created with correct page count
        let document = PDFDocument(url: url)
        #expect(document != nil)
        #expect(document?.pageCount == 3)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 1.3: Correct page dimensions from resolution

    @Test("correct page dimensions from resolution")
    func correctPageDimensionsFromResolution() throws {
        let generator = PDFGenerator(resolution: 300)

        // 300 DPI, 2550x3300 pixels = 612x792 points (Letter)
        let image = createTestImage(width: 2550, height: 3300)
        generator.addPage(image)

        let url = temporaryFileURL()
        try generator.write(to: url)

        let document = PDFDocument(url: url)
        let page = document?.page(at: 0)
        let bounds = page?.bounds(for: .mediaBox) ?? .zero

        // Allow small floating point tolerance
        #expect(abs(bounds.width - 612) < 1)
        #expect(abs(bounds.height - 792) < 1)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 1.4: 300 DPI Letter page produces 612x792 point page

    @Test("300 DPI Letter page produces 612x792 point page")
    func letterPageAt300DPI() throws {
        let generator = PDFGenerator(resolution: 300)

        // Letter: 8.5" x 11" at 300 DPI = 2550 x 3300 pixels
        let image = createTestImage(width: 2550, height: 3300)
        generator.addPage(image)

        let url = temporaryFileURL()
        try generator.write(to: url)

        let document = PDFDocument(url: url)
        let page = document?.page(at: 0)
        let bounds = page?.bounds(for: .mediaBox) ?? .zero

        // Letter in points: 8.5 * 72 = 612, 11 * 72 = 792
        #expect(abs(bounds.width - 612) < 1)
        #expect(abs(bounds.height - 792) < 1)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 1.5: 150 DPI produces larger point dimensions

    @Test("150 DPI produces larger point dimensions")
    func largerDimensionsAt150DPI() throws {
        let generator = PDFGenerator(resolution: 150)

        // Same pixel dimensions, but at 150 DPI = twice the physical size
        let image = createTestImage(width: 2550, height: 3300)
        generator.addPage(image)

        let url = temporaryFileURL()
        try generator.write(to: url)

        let document = PDFDocument(url: url)
        let page = document?.page(at: 0)
        let bounds = page?.bounds(for: .mediaBox) ?? .zero

        // At 150 DPI: 2550 * 72 / 150 = 1224, 3300 * 72 / 150 = 1584
        #expect(abs(bounds.width - 1224) < 1)
        #expect(abs(bounds.height - 1584) < 1)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 1.6: Reset clears pages for reuse

    @Test("reset clears pages for reuse")
    func resetClearsPagesForReuse() throws {
        let generator = PDFGenerator(resolution: 300)

        // Add pages
        generator.addPage(createTestImage(width: 100, height: 100))
        generator.addPage(createTestImage(width: 100, height: 100))
        #expect(generator.pageCount == 2)

        // Reset
        generator.reset()
        #expect(generator.pageCount == 0)

        // Add new page and write
        generator.addPage(createTestImage(width: 200, height: 200))
        #expect(generator.pageCount == 1)

        let url = temporaryFileURL()
        try generator.write(to: url)

        let document = PDFDocument(url: url)
        #expect(document?.pageCount == 1)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 1.7: Empty PDF (no pages) handling

    @Test("empty PDF throws error")
    func emptyPDFThrowsError() throws {
        let generator = PDFGenerator(resolution: 300)
        let url = temporaryFileURL()

        #expect(throws: PDFGeneratorError.noPages) {
            try generator.write(to: url)
        }
    }

    // MARK: - Additional tests

    @Test("mixed page sizes in single PDF")
    func mixedPageSizes() throws {
        let generator = PDFGenerator(resolution: 300)

        // Letter page
        generator.addPage(createTestImage(width: 2550, height: 3300))
        // A4 page (different dimensions)
        generator.addPage(createTestImage(width: 2480, height: 3508))
        // Legal page
        generator.addPage(createTestImage(width: 2550, height: 4200))

        let url = temporaryFileURL()
        try generator.write(to: url)

        let document = PDFDocument(url: url)
        #expect(document?.pageCount == 3)

        // Verify each page has different dimensions
        let page0 = document?.page(at: 0)?.bounds(for: .mediaBox) ?? .zero
        let page1 = document?.page(at: 1)?.bounds(for: .mediaBox) ?? .zero
        let page2 = document?.page(at: 2)?.bounds(for: .mediaBox) ?? .zero

        // Pages should have different heights
        #expect(page0.height != page1.height || page0.width != page1.width)
        #expect(page0.height != page2.height)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }
}
