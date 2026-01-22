import Foundation
import CoreGraphics

/// Generates PDF documents from scanned images
public final class PDFGenerator {
    private var pages: [CGImage] = []
    private let resolution: Int

    /// Creates a PDFGenerator with the specified scan resolution
    /// - Parameter resolution: The scan resolution in DPI (default: 300)
    public init(resolution: Int = 300) {
        self.resolution = resolution
    }

    /// Add a page to the PDF
    /// - Parameter image: The scanned image to add as a page
    public func addPage(_ image: CGImage) {
        pages.append(image)
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

        // Create PDF context with nil mediaBox (we'll set per-page)
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw PDFGeneratorError.contextCreationFailed
        }

        // Add each page
        for image in pages {
            var pageRect = pageRect(for: image)

            // Create page info dictionary with media box
            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: Data(bytes: &pageRect, count: MemoryLayout<CGRect>.size)
            ]

            context.beginPDFPage(pageInfo as CFDictionary)

            // Draw image filling the page
            context.draw(image, in: pageRect)

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
}

/// Errors that can occur during PDF generation
public enum PDFGeneratorError: Error, LocalizedError {
    case noPages
    case contextCreationFailed
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .noPages:
            return "No pages to write"
        case .contextCreationFailed:
            return "Failed to create PDF context"
        case .writeFailed:
            return "Failed to write PDF file"
        }
    }
}
