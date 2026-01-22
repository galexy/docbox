# Phase 2: PDF Generation

**Date:** 2026-01-21
**Branch:** `phase2-pdf-generation`
**Issue:** https://github.com/galexy/docbox/issues/2

## Overview

This phase adds PDF output capability. Scanned images become PDF documents. The text layer (OCR) is deferred to Phase 3, so PDFs in this phase are image-only (not searchable).

## Deliverables

- PDFGenerator class
- Image-to-PDF conversion with correct dimensions
- Multi-page PDF support
- CLI outputs PDF files (in addition to existing TIFF/PNG support)

## Detailed Design

### PDFGenerator

A class that creates PDF documents from scanned images:

```swift
public final class PDFGenerator {
    private var pages: [CGImage] = []
    private var resolution: Int

    public init(resolution: Int = 300)

    /// Add a page to the PDF
    public func addPage(_ image: CGImage)

    /// Write the PDF to a file
    public func write(to url: URL) throws

    /// Reset for reuse
    public func reset()
}
```

### Page Dimensions

PDF uses 72 points per inch. To convert from scan pixels to PDF points:

```
pointWidth = pixelWidth * 72 / resolution
pointHeight = pixelHeight * 72 / resolution
```

For a 300 DPI scan of Letter paper (8.5" × 11"):
- Pixels: 2550 × 3300
- Points: 612 × 792

### PDF Creation Strategy

Use Core Graphics to create the PDF:

1. Create `CGContext` with `CGContext(url:mediaBox:_:)`
2. For each page:
   - Call `context.beginPDFPage(nil)` with media box
   - Draw the image with `context.draw(image, in: rect)`
   - Call `context.endPDFPage()`
3. Call `context.closePDF()`

This approach is simpler than PDFKit for image-only PDFs and gives us direct control over the drawing.

### CLI Integration

Detect `.pdf` extension and use PDFGenerator:

```swift
let ext = URL(fileURLWithPath: output).pathExtension.lowercased()
switch ext {
case "pdf":
    // Use PDFGenerator for multi-page PDF
case "tiff", "tif":
    // Use existing multi-page TIFF
default:
    // Use existing multiple PNG files
}
```

## Tasks

### Unit Tests

#### 1. PDFGenerator Tests
- [ ] 1.1 Single page PDF creation
- [ ] 1.2 Multi-page PDF creation
- [ ] 1.3 Correct page dimensions from resolution
- [ ] 1.4 300 DPI Letter page produces 612×792 point page
- [ ] 1.5 150 DPI produces larger point dimensions
- [ ] 1.6 Reset clears pages for reuse
- [ ] 1.7 Empty PDF (no pages) handling

### Integration Tests

#### 2. CLI PDF Output Tests
- [ ] 2.1 Scan to PDF produces valid PDF file
- [ ] 2.2 Multi-page scan creates multi-page PDF
- [ ] 2.3 PDF page count matches scanned page count

### Implementation

#### 3. PDFGenerator Class
- [ ] 3.1 Create PDFGenerator in DocboxKit
- [ ] 3.2 Implement addPage method
- [ ] 3.3 Implement write method with Core Graphics
- [ ] 3.4 Implement reset method
- [ ] 3.5 Handle resolution-to-points conversion

#### 4. CLI Updates
- [ ] 4.1 Add PDF output support based on file extension
- [ ] 4.2 Pass scan resolution to PDFGenerator
- [ ] 4.3 Update help text and documentation
