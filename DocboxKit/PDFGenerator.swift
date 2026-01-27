import Foundation
import CoreGraphics
import CoreText
import PDFKit

/// A page with its image and optional text observations
private struct PageContent {
    let image: CGImage
    let textObservations: [TextObservation]
}

/// Generates PDF documents from scanned images
public final class PDFGenerator {
    private var pages: [PageContent] = []
    private let resolution: Int
    private let compressImages: Bool

    /// Creates a PDFGenerator with the specified scan resolution
    /// - Parameters:
    ///   - resolution: The scan resolution in DPI (default: 300)
    ///   - compressImages: Whether to compress images as JPEG (default: true)
    public init(resolution: Int = 300, compressImages: Bool = true) {
        self.resolution = resolution
        self.compressImages = compressImages
    }

    /// Add a page to the PDF
    /// - Parameters:
    ///   - image: The scanned image to add as a page
    ///   - textObservations: Optional array of text observations for searchable text layer
    public func addPage(_ image: CGImage, textObservations: [TextObservation] = []) {
        pages.append(PageContent(image: image, textObservations: textObservations))
    }

    /// The number of pages currently added
    public var pageCount: Int {
        return pages.count
    }

    /// Write the PDF to a file
    /// - Parameter url: The file URL to write to
    /// - Throws: PDFGeneratorError if writing fails
    public func write(to url: URL) throws {
        guard !pages.isEmpty else {
            throw PDFGeneratorError.noPages
        }

        if compressImages {
            // Two-stage write: Core Graphics → PDFKit with JPEG compression
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".pdf")

            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            // Write uncompressed PDF to temp location
            try writeWithCoreGraphics(to: tempURL)

            // Load with PDFKit and re-save with JPEG compression
            guard let document = PDFDocument(url: tempURL) else {
                throw PDFGeneratorError.compressionFailed
            }

            let options: [PDFDocumentWriteOption: Any] = [
                .saveImagesAsJPEGOption: true
            ]

            guard document.write(to: url, withOptions: options) else {
                throw PDFGeneratorError.compressionFailed
            }
        } else {
            // Direct write without compression
            try writeWithCoreGraphics(to: url)
        }
    }

    /// Write PDF using Core Graphics (internal implementation)
    private func writeWithCoreGraphics(to url: URL) throws {
        // Create PDF context with nil mediaBox (we'll set per-page)
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw PDFGeneratorError.contextCreationFailed
        }

        // Add each page
        for page in pages {
            var pageRect = pageRect(for: page.image)

            // Create page info dictionary with media box
            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: Data(bytes: &pageRect, count: MemoryLayout<CGRect>.size)
            ]

            context.beginPDFPage(pageInfo as CFDictionary)

            // Draw image filling the page
            context.draw(page.image, in: pageRect)

            // Draw invisible text layer for searchability
            if !page.textObservations.isEmpty {
                drawTextLayer(context: context, observations: page.textObservations, pageRect: pageRect)
            }

            context.endPDFPage()
        }

        context.closePDF()
    }

    /// Reset the generator for reuse
    public func reset() {
        pages.removeAll()
    }

    // MARK: - Private

    /// Calculate the PDF page rectangle for an image
    /// PDF uses 72 points per inch
    private func pageRect(for image: CGImage) -> CGRect {
        let pointsPerInch: CGFloat = 72.0
        let dpi = CGFloat(resolution)

        let width = CGFloat(image.width) * pointsPerInch / dpi
        let height = CGFloat(image.height) * pointsPerInch / dpi

        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    /// Draw invisible text layer for searchability
    private func drawTextLayer(context: CGContext, observations: [TextObservation], pageRect: CGRect) {
        context.saveGState()

        // Set text to invisible (fully transparent)
        context.setTextDrawingMode(.fill)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))

        for observation in observations {
            // Convert normalized bounding box to page coordinates
            let textRect = CGRect(
                x: observation.boundingBox.origin.x * pageRect.width,
                y: observation.boundingBox.origin.y * pageRect.height,
                width: observation.boundingBox.width * pageRect.width,
                height: observation.boundingBox.height * pageRect.height
            )

            // Calculate font size to fit text in bounding box
            let fontSize = calculateFontSize(for: observation.text, in: textRect)

            // Create attributed string with Helvetica font
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 0)
            ]
            let attributedString = CFAttributedStringCreate(nil, observation.text as CFString, attributes as CFDictionary)!

            // Create CTLine and draw
            let line = CTLineCreateWithAttributedString(attributedString)

            // Position at bottom-left of bounding box
            context.textPosition = CGPoint(x: textRect.origin.x, y: textRect.origin.y)
            CTLineDraw(line, context)
        }

        context.restoreGState()
    }

    /// Calculate font size to approximately fit text width in bounding box
    private func calculateFontSize(for text: String, in rect: CGRect) -> CGFloat {
        // Start with a reasonable font size based on box height
        let targetHeight = rect.height * 0.8
        var fontSize = targetHeight

        // Use Helvetica to measure text width
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]
        let attributedString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributedString)
        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)

        // Scale font size to fit width if needed
        if textWidth > 0 && rect.width > 0 {
            let scaleFactor = rect.width / textWidth
            if scaleFactor < 1.0 {
                fontSize *= scaleFactor
            }
        }

        // Ensure minimum readable size
        return max(fontSize, 1.0)
    }
}

/// Errors that can occur during PDF generation
public enum PDFGeneratorError: Error, LocalizedError {
    case noPages
    case contextCreationFailed
    case writeFailed
    case compressionFailed

    public var errorDescription: String? {
        switch self {
        case .noPages:
            return "No pages to write"
        case .contextCreationFailed:
            return "Failed to create PDF context"
        case .writeFailed:
            return "Failed to write PDF file"
        case .compressionFailed:
            return "Failed to compress PDF"
        }
    }
}
