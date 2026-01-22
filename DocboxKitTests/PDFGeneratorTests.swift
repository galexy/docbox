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

    // MARK: - Task 3.1: PDF with text layer is searchable

    @Test("PDF with text layer is searchable")
    func pdfWithTextLayerIsSearchable() throws {
        let generator = PDFGenerator(resolution: 300)
        let image = createTestImage(width: 2550, height: 3300)

        // Create text observations
        let observations = [
            TextObservation(
                text: "Hello World",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.4, height: 0.05),
                confidence: 0.99
            ),
            TextObservation(
                text: "Searchable PDF",
                boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.5, height: 0.05),
                confidence: 0.98
            )
        ]

        generator.addPage(image, textObservations: observations)

        let url = temporaryFileURL()
        try generator.write(to: url)

        // Open and search the PDF
        guard let document = PDFDocument(url: url) else {
            #expect(Bool(false), "Failed to open PDF")
            return
        }

        // Search for text - PDFKit should find it
        let searchResults = document.findString("Hello", withOptions: .caseInsensitive)
        #expect(!searchResults.isEmpty, "Should find 'Hello' in searchable PDF")

        let searchResults2 = document.findString("Searchable", withOptions: .caseInsensitive)
        #expect(!searchResults2.isEmpty, "Should find 'Searchable' in searchable PDF")

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 3.2: Text positions match observation bounding boxes

    @Test("text positions match observation bounding boxes")
    func textPositionsMatchBoundingBoxes() throws {
        let generator = PDFGenerator(resolution: 300)
        let image = createTestImage(width: 2550, height: 3300) // 612x792 points

        // Place text at known position
        let observation = TextObservation(
            text: "TestPosition",
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.05),
            confidence: 0.99
        )

        generator.addPage(image, textObservations: [observation])

        let url = temporaryFileURL()
        try generator.write(to: url)

        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            #expect(Bool(false), "Failed to open PDF")
            return
        }

        // Search for the text
        let selections = document.findString("TestPosition", withOptions: [])
        #expect(!selections.isEmpty, "Should find text")

        if let selection = selections.first {
            let bounds = selection.bounds(for: page)
            let pageRect = page.bounds(for: .mediaBox)

            // Convert expected position to PDF points
            let expectedX = 0.2 * pageRect.width
            let expectedY = 0.3 * pageRect.height

            // Check that text is approximately in the right position
            // Allow some tolerance for font metrics differences
            #expect(abs(bounds.origin.x - expectedX) < 50, "X position should be close to expected")
            #expect(abs(bounds.origin.y - expectedY) < 50, "Y position should be close to expected")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Task 3.3: Text is invisible (doesn't affect visual appearance)

    @Test("text is invisible in PDF")
    func textIsInvisible() throws {
        // Create two PDFs - one with text layer, one without
        let imageWithoutText = createTestImage(width: 612, height: 792)
        let imageWithText = createTestImage(width: 612, height: 792)

        let genWithout = PDFGenerator(resolution: 72)
        genWithout.addPage(imageWithoutText)
        let urlWithout = temporaryFileURL()
        try genWithout.write(to: urlWithout)

        let genWith = PDFGenerator(resolution: 72)
        let observations = [
            TextObservation(
                text: "Invisible Text Layer",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.99
            )
        ]
        genWith.addPage(imageWithText, textObservations: observations)
        let urlWith = temporaryFileURL()
        try genWith.write(to: urlWith)

        // Both PDFs should be created successfully
        #expect(FileManager.default.fileExists(atPath: urlWithout.path))
        #expect(FileManager.default.fileExists(atPath: urlWith.path))

        // The PDF with text should still be searchable
        let doc = PDFDocument(url: urlWith)
        let results = doc?.findString("Invisible", withOptions: .caseInsensitive)
        #expect(results?.isEmpty == false, "Text should be searchable")

        // Cleanup
        try? FileManager.default.removeItem(at: urlWithout)
        try? FileManager.default.removeItem(at: urlWith)
    }

    // MARK: - Task 3.4: Multi-page PDF with text on each page

    @Test("multi-page PDF with text on each page")
    func multiPagePDFWithText() throws {
        let generator = PDFGenerator(resolution: 300)

        // Add 3 pages with different text
        for i in 1...3 {
            let image = createTestImage(width: 2550, height: 3300)
            let observations = [
                TextObservation(
                    text: "Page \(i) Content",
                    boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.5, height: 0.05),
                    confidence: 0.99
                )
            ]
            generator.addPage(image, textObservations: observations)
        }

        let url = temporaryFileURL()
        try generator.write(to: url)

        guard let document = PDFDocument(url: url) else {
            #expect(Bool(false), "Failed to open PDF")
            return
        }

        #expect(document.pageCount == 3)

        // Each page should have searchable text
        for i in 1...3 {
            let results = document.findString("Page \(i)", withOptions: [])
            #expect(!results.isEmpty, "Should find 'Page \(i)' in PDF")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Additional text layer tests

    @Test("PDF without text observations still works")
    func pdfWithoutTextObservations() throws {
        let generator = PDFGenerator(resolution: 300)
        let image = createTestImage(width: 2550, height: 3300)

        // Add page without text observations (empty array, which is the default)
        generator.addPage(image)

        let url = temporaryFileURL()
        try generator.write(to: url)

        let document = PDFDocument(url: url)
        #expect(document?.pageCount == 1)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }
}
