# docbox Design Document

## Overview

docbox is a command-line application for macOS that scans physical documents, performs OCR, and generates searchable PDF files. The application uses three Apple frameworks:

- **ImageCaptureCore** — Scanner discovery and image capture
- **Vision** — Optical character recognition via VNRecognizeTextRequest
- **PDFKit** — PDF document generation

## Architecture

The application follows a concurrent pipeline architecture where scanning overlaps with OCR processing:

```
┌─────────────────────────────────────────────────────────────────┐
│ Time →                                                          │
├─────────────────────────────────────────────────────────────────┤
│ Scanner:  [scan p1]──[scan p2]──[scan p3]──[scan p4]            │
│ OCR:              ╲──[ocr p1]──[ocr p2]──[ocr p3]──[ocr p4]     │
│ PDF:                       ╲──[pdf p1]──[pdf p2]──[pdf p3]──... │
└─────────────────────────────────────────────────────────────────┘
```

As soon as a page finishes scanning, it enters the OCR stage while the next page begins scanning. This overlaps I/O-bound scanning with CPU-bound OCR, roughly doubling throughput for multi-page documents.

### Module Structure

- **ScannerManager** — Handles device discovery, session management, and scan execution; produces an `AsyncStream<CGImage>` of scanned pages
- **OCRProcessor** — Performs text recognition on scanned images; transforms pages into `(CGImage, [TextObservation])` tuples
- **PDFGenerator** — Creates PDF documents with embedded images and invisible text layers; consumes processed pages
- **CLI** — Parses arguments and orchestrates the pipeline

### Concurrency Model

The pipeline uses Swift's structured concurrency:

```swift
// Conceptual flow
let pages = scannerManager.scanPages()  // AsyncStream<CGImage>

await withTaskGroup(of: Void.self) { group in
    for await image in pages {
        group.addTask {
            let observations = await ocrProcessor.recognize(image)
            await pdfGenerator.addPage(image: image, text: observations)
        }
    }
}

pdfGenerator.write(to: outputURL)
```

The scanner produces pages into an `AsyncStream`. A task group consumes pages as they arrive, running OCR and adding to the PDF. The task group limits concurrency naturally—while one page undergoes OCR, the scanner can be capturing the next.

To preserve page order in the PDF, the PDFGenerator accepts pages with sequence numbers and assembles them in order before writing.

## Scanner Discovery and Control

### Device Browser Architecture

ImageCaptureCore provides scanner access through a browser-delegate pattern. The `ICDeviceBrowser` class discovers connected scanners by continuously monitoring USB, network (Bonjour), and shared devices. When started, it notifies its delegate as devices appear and disappear.

The browser operates asynchronously. After calling `start()`, device discovery happens over time through delegate callbacks rather than returning a list synchronously. This requires the application to either wait for a discovery period or maintain a persistent browser that updates a device list as scanners come and go.

For a command-line tool, the practical approach is to start the browser, wait briefly for discovery (1-2 seconds typically suffices for local USB scanners), then either list available devices or proceed with a scan operation.

**Important implementation detail:** The device browser must remain running throughout the scanning operation. Stopping the browser invalidates device handles, causing subsequent session open requests to fail with "Failed to open a connection to the device." The browser should only be stopped when the application exits or no longer needs scanner access.

### Scanner Sessions

Scanners require exclusive access — only one application can control a scanner at a time. Before scanning, the application must request a session using `requestOpenSession()`. The request may fail if another application already holds the scanner. After scanning completes, the session should be closed to release the device.

The session model means docbox cannot scan while another application (such as Image Capture or Preview) has the scanner open. The application should handle this gracefully with clear error messages.

**Important implementation detail:** After `requestOpenSession()` succeeds, the application must wait for the `deviceDidBecomeReady(_:)` delegate callback before proceeding. The device's functional unit list is empty until this callback fires. Attempting to select a functional unit before the device is ready will fail or produce undefined behavior.

When a session open fails because another client holds the scanner, the `scannerDeviceDidBecomeAvailable(_:)` delegate callback will fire when that client releases it. The application can then retry opening the session.

### Functional Units

A scanner device exposes one or more functional units, each representing a different scanning mechanism:

- **Flatbed** — The glass scanning surface for single pages or items
- **Document Feeder** — Automatic document feeder (ADF) for multi-page scanning
- **Transparency Units** — For scanning slides and negatives (not relevant for document scanning)

The document feeder is the primary target for docbox since it handles the typical "inbox" workflow of scanning multiple pages. However, flatbed support is valuable as a fallback and for non-standard documents.

Each functional unit reports its own capabilities: supported resolutions, color modes, document sizes, and special features like duplex scanning. The application must query these capabilities and validate user options against what the selected unit actually supports.

### Scan Configuration

Before initiating a scan, the functional unit must be configured. Key parameters include:

**Resolution** — Specified in DPI. Scanners report both a full range of supported resolutions and a subset of preferred resolutions. Common values are 150, 300, and 600 DPI. For document archival, 300 DPI provides a good balance between file size and readability. The application should validate that the requested resolution is supported.

**Color Mode** — Specified through pixel data type and bit depth. The relevant modes for documents are:
- Black and white (1-bit) — Smallest files, suitable for text-only documents
- Grayscale (8-bit) — Good for documents with pencil marks or varying ink density
- Color RGB (24-bit) — Required for documents with color content

**Scan Area** — A rectangle specifying what portion of the scanning surface to capture. For document feeders, this typically matches the document size. For flatbed, it could be customized to scan specific regions.

**Document Type** — Predefined paper sizes (Letter, A4, Legal, etc.). The functional unit reports which document types it supports. Setting the document type automatically configures the scan area to match.

**Duplex** — For document feeders that support it, enables scanning both sides of each page. The feeder reports whether duplex is available through `supportsDuplexScanning`.

### Scan Execution

Scans can transfer data in two modes:

**File-based transfer** — The scanner driver writes completed scans directly to files. The application specifies a download directory, filename, and format (JPEG, TIFF, PNG). Simpler to implement but requires disk I/O for intermediate files.

**Memory-based transfer** — Scan data arrives as bands (horizontal strips) through delegate callbacks. The application assembles bands into a complete image in memory.

For docbox, memory-based transfer is the preferred approach. This enables a clean pipeline with no intermediate files:

1. Receive scan bands and assemble into a CGImage
2. Pass CGImage directly to VNImageRequestHandler for OCR
3. Use the same CGImage plus OCR results to generate the PDF page

The only file written is the final PDF output.

#### Band Assembly

Before scanning, the application allocates a pixel buffer based on the scan area dimensions and resolution. As each band arrives via `scannerDevice(_:didScanToBandData:)`, its data is copied into the correct offset in the buffer. The band data object provides:

- `fullImageWidth` and `fullImageHeight` — Total image dimensions
- `bitsPerPixel`, `bitsPerComponent` — Pixel format details
- `bytesPerRow` — Row stride for the image data
- `dataStartRow` — Vertical offset for this band
- `dataNumRows` — Number of rows in this band
- `dataBuffer` — The actual pixel data

After the final band arrives (signaled by `scannerDevice(_:didCompleteScanWithError:)`), the application constructs a CGImage from the assembled buffer using `CGImage(width:height:bitsPerComponent:bitsPerPixel:bytesPerRow:space:bitmapInfo:provider:decode:shouldInterpolate:intent:)`.

### Asynchronous Flow

All scanner operations are asynchronous. Requesting a scan returns immediately; results arrive through delegate callbacks:

- `scannerDevice(_:didScanToBandData:)` — Called for each band of image data (memory-based mode)
- `scannerDevice(_:didCompleteScanWithError:)` — Called when scanning finishes (success or failure)

For a command-line tool, this asynchronous model requires either a run loop to process callbacks or dispatch semaphores to block until operations complete. The latter approach keeps the code simpler for a sequential pipeline.

## Optical Character Recognition

### Vision Framework Approach

The Vision framework performs OCR through request objects processed by an image request handler. The pattern is:

1. Create a `VNImageRequestHandler` with the source image
2. Create a `VNRecognizeTextRequest` with a completion handler
3. Execute the request through the handler
4. Extract recognized text from the request's results

The completion handler receives an array of `VNRecognizedTextObservation` objects, each representing a detected text region. Each observation provides candidate strings ranked by confidence, along with bounding box coordinates.

### Recognition Levels

VNRecognizeTextRequest offers two recognition levels:

**Accurate** — Uses a neural network for higher accuracy, especially with challenging fonts, angles, or image quality. This is slower but produces better results. For archival document scanning, accurate recognition is worth the additional processing time.

**Fast** — Uses a simpler algorithm optimized for speed. Suitable for real-time applications but may miss text or produce more errors.

### Language Support

The recognizer supports multiple languages and can be configured with a prioritized list. For English documents, the default configuration works well. The `supportedRecognitionLanguages(for:revision:)` class method returns available languages.

### Extracting Results

Each `VNRecognizedTextObservation` contains:

- **Bounding box** — Normalized coordinates (0.0 to 1.0) of the text region, with origin at bottom-left (Core Graphics coordinate system)
- **Top candidates** — Array of recognized strings with confidence scores

The bounding boxes are essential for creating a searchable PDF, as they specify where to position the invisible text layer to align with the visible scanned image.

Coordinate transformation is required when applying these boxes to PDF generation. Vision uses normalized coordinates with bottom-left origin, which matches PDF coordinates, but the values must be scaled to the actual page dimensions.

### Processing Pipeline

For multi-page documents, OCR runs independently on each page. The results (text strings with positions) are stored alongside the page images for the PDF generation stage. Processing pages in parallel is possible but may not provide significant benefit for typical document batches, and sequential processing simplifies memory management.

## PDF Generation

### Searchable PDF Architecture

A searchable PDF contains two layers:

1. **Visible layer** — The scanned image, displayed to the user
2. **Invisible text layer** — OCR results positioned to match the image, enabling search and copy operations

When a user searches the PDF or selects text to copy, they interact with the invisible text layer. The visual feedback (highlighting) aligns with the visible image because the text positions match the original character locations in the scan.

### PDF Creation Strategy

PDFKit provides `PDFDocument` and `PDFPage` classes for working with PDF files, but creating pages with custom content requires drawing directly using Core Graphics.

The approach involves:

1. Create a graphics context targeting PDF output
2. For each page:
   - Begin a new PDF page with appropriate dimensions
   - Draw the scanned image filling the page
   - Draw OCR text at recognized positions with zero alpha (invisible)
3. Finalize the PDF

The page dimensions derive from the scan resolution and image size. A 300 DPI scan of a Letter-sized page (8.5" × 11") produces an image of 2550 × 3300 pixels. In PDF coordinates (72 points per inch), this becomes 612 × 792 points.

### Text Layer Implementation

Drawing invisible text requires care:

**Font sizing** — The text must be sized so that character widths approximately match the bounding boxes from OCR. Exact matching is difficult due to proportional fonts, but close approximation suffices for search functionality.

**Positioning** — Convert Vision's normalized coordinates to PDF points. Since both use bottom-left origin, this is a straightforward scale transformation.

**Invisibility** — Set the text fill color to fully transparent (alpha = 0). The text renders to the PDF structure for search indexing but doesn't appear visually.

**Font selection** — A standard sans-serif font like Helvetica works for most documents. The actual font appearance doesn't matter since the text is invisible; only character positions matter for selection feedback.

### Multi-Page Documents

Each scanned page becomes a PDF page. Pages should maintain consistent dimensions when the source documents are uniform, but the system handles mixed sizes by setting each page's media box to match its image dimensions.

#### Page Ordering

With concurrent OCR processing, pages may complete out of order (a fast page might finish OCR before a slow one that started earlier). The PDFGenerator maintains a sequence number for each page and assembles them in the correct order before writing. Internally, it can either:

1. Buffer completed pages and insert them at the correct position
2. Pre-allocate page slots and fill them as processing completes

The first approach is simpler; the second avoids reordering overhead for large documents.

The final `PDFDocument` can be written directly to a file. PDFKit handles compression and formatting automatically.

## Command-Line Interface

### Argument Structure

The CLI uses a verb-based structure:

```
docbox list                    # List available scanners
docbox scan [options] output   # Scan to PDF
```

### Scan Options

**Scanner selection:**
- `--scanner <name>` — Select scanner by name (partial match supported)
- Default: Use first available scanner

**Input source:**
- `--flatbed` — Use flatbed instead of document feeder
- `--duplex` — Enable duplex scanning (if supported)

**Scan quality:**
- `--resolution <dpi>` — Set scan resolution (default: 300)
- `--color` — Scan in color (default)
- `--grayscale` — Scan in grayscale
- `--mono` — Scan in black and white

**Document handling:**
- `--page-size <size>` — Set page size: letter, legal, a4 (default: letter)

**Output:**
- Output filename is a required positional argument
- Extension determines format (.pdf required for searchable output)

### Error Handling

The CLI reports errors through stderr with meaningful messages:

- Scanner not found or busy
- Unsupported option for the selected scanner
- No pages in document feeder
- OCR failures (with partial output option)
- File write failures

Exit codes follow Unix conventions: 0 for success, non-zero for errors.

## Implementation Phases

### Phase 1: Scanner Discovery and Basic Scanning

Implement scanner discovery and image capture with memory-based transfer. This phase captures scanned images into memory as CGImage objects.

Deliverables:
- ScannerManager class with device discovery
- Scanner session management
- Functional unit selection and configuration
- Band assembly into CGImage
- Basic CLI with `list` command and `scan` command (outputs PNG for testing)

### Phase 2: PDF Generation

Add PDF output capability. Scanned images become PDF documents, but without text layer (not searchable).

Deliverables:
- PDFGenerator class
- Image-to-PDF conversion with correct dimensions
- Multi-page PDF support
- CLI outputs PDF files

### Phase 3: OCR Integration

Complete the pipeline by adding text recognition and searchable PDF generation.

Deliverables:
- OCRProcessor class using VNRecognizeTextRequest
- Invisible text layer in generated PDFs
- Full searchable PDF output

## Technical Considerations

### Run Loop and Concurrency

ImageCaptureCore requires a run loop for delegate callbacks. The application bridges this to Swift concurrency using `AsyncStream` with continuations:

```swift
func scanPages() -> AsyncStream<CGImage> {
    AsyncStream { continuation in
        self.continuation = continuation
        // Start scan; delegate callbacks will yield pages
        scannerDevice.requestScan()
    }
}

// In delegate callback:
func scannerDevice(_ device: ICScannerDevice, didCompleteScanWithError error: Error?) {
    if let image = assembleImage() {
        continuation.yield(image)
    }
    // For document feeder, continues until no more pages
}
```

The main function uses `@main` with an async entry point, which provides the necessary run loop integration for both ImageCaptureCore callbacks and Swift concurrency.

### Memory Management

Scanned images can be large. A single Letter-page color scan at 300 DPI is approximately 24 MB uncompressed (2550 × 3300 pixels × 3 bytes). The pipelined approach means up to two pages may be in memory simultaneously—one being scanned, one undergoing OCR.

Memory considerations:

- Peak memory usage: ~50 MB for two Letter pages in flight (acceptable for modern systems)
- Pages are released after being added to the PDF
- The AsyncStream provides natural backpressure—if OCR falls behind, the stream buffers minimally before the scanner blocks
- The PDF document accumulates pages with compressed image data, keeping its memory footprint modest
- Use autoreleasepool blocks around page processing to ensure timely deallocation

### Sandbox and Entitlements

ImageCaptureCore requires the `com.apple.security.device.usb` entitlement for USB scanners. Network scanners may require additional network entitlements. For development, running without sandbox simplifies initial implementation.

The application needs read/write access to the output directory, which is straightforward for command-line tools running outside the sandbox.

## Testing Strategy

### Unit Test Categories

#### Scanner Manager Tests

The scanner hardware dependency requires protocol-based abstraction for testing. Tests use mock implementations of scanner device and browser protocols.

- **Device discovery** — Verify delegate callbacks correctly populate device list; handle devices appearing and disappearing
- **Session management** — Test open/close session lifecycle; handle "device busy" errors
- **Configuration validation** — Verify requested resolution/color/page size against mock capability sets; reject unsupported configurations
- **Band assembly** — Test pixel buffer assembly from mock band data; verify correct handling of various pixel formats (RGB, grayscale, monochrome) and bit depths
- **Error handling** — Simulate scan failures mid-page, device disconnection, timeout scenarios

#### OCR Processor Tests

Vision framework can be tested with fixture images.

- **Text extraction** — Verify correct text extraction from sample document images with known content
- **Bounding boxes** — Validate that returned coordinates correctly locate text regions
- **Blank pages** — Handle pages with no detectable text gracefully
- **Mixed content** — Documents with text, images, and whitespace
- **Orientation** — Verify recognition works for rotated content (if supported)

#### PDF Generator Tests

Output can be verified by reading back the generated PDF.

- **Single page** — Generate PDF from one image; verify dimensions and image presence
- **Multi-page assembly** — Correct page count and order
- **Out-of-order insertion** — Pages added with sequence numbers 3, 1, 2 produce correct 1, 2, 3 order
- **Text layer** — Verify invisible text is present and searchable (use PDFKit to extract text from generated PDF)
- **Text positioning** — Verify text layer coordinates align with expected positions
- **Mixed page sizes** — Handle documents with varying page dimensions

#### CLI Tests

Argument parsing tested in isolation.

- **Valid arguments** — All option combinations parse correctly
- **Scanner selection** — Partial name matching works as expected
- **Invalid arguments** — Appropriate error messages for unknown options, missing values
- **Mutually exclusive options** — Error when conflicting options specified (e.g., `--color` and `--mono`)

#### Integration Tests

End-to-end pipeline tests with mock scanner providing fixture image data.

- **Full pipeline** — Mock scan data flows through OCR to PDF; verify output is searchable PDF with correct content
- **Multi-page concurrent** — Verify page ordering preserved under concurrent OCR processing
- **Backpressure** — Slow OCR processing doesn't cause unbounded memory growth
- **Error propagation** — Scanner error mid-batch produces partial output or appropriate error

### Test Fixtures

- Sample document images (Letter size, 300 DPI) with known text content
- Mock band data representing various scan configurations
- Expected OCR output for fixture images

## References

- [ImageCaptureCore Framework](https://developer.apple.com/documentation/imagecapturecore)
- [ICScannerDevice](https://developer.apple.com/documentation/imagecapturecore/icscannerdevice)
- [ICScannerFunctionalUnit](https://developer.apple.com/documentation/imagecapturecore/icscannerfunctionalunit)
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [PDFKit](https://developer.apple.com/documentation/pdfkit)
- [Creating a PDF in Swift with PDFKit](https://www.kodeco.com/4023941-creating-a-pdf-in-swift-with-pdfkit)
- [Vision Framework OCR](https://www.hackingwithswift.com/example-code/vision/how-to-use-vnrecognizetextrequests-optical-character-recognition-to-detect-text-in-an-image)
