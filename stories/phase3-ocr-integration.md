# Phase 3: OCR Integration

**Date:** 2026-01-21
**Branch:** `phase3-ocr-integration`
**Issue:** https://github.com/galexy/docbox/issues/4

## Overview

Complete the pipeline by adding text recognition and searchable PDF generation. This phase adds:
- OCRProcessor class using Vision framework's VNRecognizeTextRequest
- Invisible text layer in generated PDFs
- Full searchable PDF output

## Deliverables

- OCRProcessor class
- TextObservation type for OCR results
- Updated PDFGenerator with text layer support
- CLI integration with OCR pipeline

## Detailed Design

### TextObservation

A value type representing recognized text with its position:

```swift
public struct TextObservation {
    /// The recognized text string
    public let text: String

    /// Bounding box in normalized coordinates (0.0-1.0), bottom-left origin
    public let boundingBox: CGRect

    /// Recognition confidence (0.0-1.0)
    public let confidence: Float
}
```

### OCRProcessor

Performs text recognition on images:

```swift
public final class OCRProcessor {
    public enum RecognitionLevel {
        case fast
        case accurate
    }

    public init(recognitionLevel: RecognitionLevel = .accurate)

    /// Recognize text in an image
    /// - Parameter image: The image to process
    /// - Returns: Array of text observations
    public func recognize(_ image: CGImage) async throws -> [TextObservation]
}
```

### Vision Framework Integration

1. Create `VNImageRequestHandler` with the CGImage
2. Create `VNRecognizeTextRequest` with recognition level
3. Perform the request synchronously (wrapped in async)
4. Extract `VNRecognizedTextObservation` results
5. Convert to `TextObservation` with bounding boxes

### PDFGenerator Text Layer

Update PDFGenerator to accept text observations and draw invisible text:

```swift
public func addPage(_ image: CGImage, textObservations: [TextObservation] = [])
```

For each observation:
1. Convert normalized bounding box to PDF points
2. Calculate font size to approximately match text width
3. Draw text with transparent fill color (alpha = 0)
4. Use Helvetica font for consistent rendering

### Coordinate Transformation

Vision's normalized coordinates (0.0-1.0) to PDF points:
```
pdfX = boundingBox.origin.x * pageWidth
pdfY = boundingBox.origin.y * pageHeight
pdfWidth = boundingBox.width * pageWidth
pdfHeight = boundingBox.height * pageHeight
```

Both use bottom-left origin, so no flip is needed.

### CLI Integration

Update scan pipeline:
1. Scan image
2. Run OCR on image (if outputting PDF)
3. Add page with text observations to PDFGenerator

```swift
for await image in stream {
    let observations = try await ocrProcessor.recognize(image)
    pdfGenerator.addPage(image, textObservations: observations)
}
```

## Tasks

### Unit Tests

#### 1. TextObservation Tests
- [x] 1.1 TextObservation initialization and properties
- [x] 1.2 Bounding box normalization validation

#### 2. OCRProcessor Tests
- [x] 2.1 Recognize text in image with known content
- [x] 2.2 Empty image returns empty observations
- [x] 2.3 Recognition level configuration (fast vs accurate)
- [x] 2.4 Bounding boxes are normalized (0.0-1.0)

#### 3. PDFGenerator Text Layer Tests
- [x] 3.1 PDF with text layer is searchable
- [x] 3.2 Text positions match observation bounding boxes
- [x] 3.3 Text is invisible (doesn't affect visual appearance)
- [x] 3.4 Multi-page PDF with text on each page

### Implementation

#### 4. TextObservation Type
- [x] 4.1 Create TextObservation struct
- [x] 4.2 Add text, boundingBox, confidence properties

#### 5. OCRProcessor Class
- [x] 5.1 Create OCRProcessor in DocboxKit
- [x] 5.2 Implement VNRecognizeTextRequest setup
- [x] 5.3 Implement async recognize method
- [x] 5.4 Extract observations from VNRecognizedTextObservation
- [x] 5.5 Support fast/accurate recognition levels

#### 6. PDFGenerator Updates
- [x] 6.1 Update addPage to accept text observations
- [x] 6.2 Implement coordinate transformation
- [x] 6.3 Calculate font size from bounding box
- [x] 6.4 Draw invisible text layer

#### 7. CLI Updates
- [x] 7.1 Integrate OCR into PDF scan pipeline
- [x] 7.2 Add --no-ocr flag to skip text recognition
- [x] 7.3 Update help text and documentation
