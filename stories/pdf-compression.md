# Feature: PDF Image Compression

**Date:** 2026-01-22
**Branch:** `pdf-compression`
**Issue:** https://github.com/galexy/docbox/issues/11

## Overview

Reduce PDF file sizes by compressing scanned images using JPEG encoding. Real-world testing shows **3x file size reduction** for scanned documents.

## Problem

When scanned images are embedded in PDFs using Core Graphics, they are stored with lossless Flate compression, resulting in large file sizes (10MB+ for a two-sided page).

## Solution

Use PDFKit's `saveImagesAsJPEGOption` write option to re-encode images as JPEG when saving.

### Implementation

Two-stage write process:
1. Create PDF with Core Graphics (preserves invisible text layer for searchability)
2. Load with PDFDocument and re-save with JPEG compression option

```swift
let options: [PDFDocumentWriteOption: Any] = [
    .saveImagesAsJPEGOption: true
]
document.write(to: url, withOptions: options)
```

### API

```swift
public init(resolution: Int = 300, compressImages: Bool = true)
```

- `compressImages: true` (default) - Uses JPEG compression, ~3x smaller files
- `compressImages: false` - Lossless compression, maximum quality

### CLI

```
--no-compress    Disable JPEG compression (larger files, lossless quality)
```

Compression is **enabled by default**.

## Investigation Notes

### Failed Approach: Pre-compressing Images

Initial attempt to compress images before drawing to PDF context failed because Core Graphics re-encodes images internally when drawing. The compression was undone.

### Correct API Names

The PDFKit write options are:
- `.saveImagesAsJPEGOption` - JPEG encode all images
- `.optimizeImagesForScreenOption` - Downsample to screen resolution
- `.burnInAnnotationsOption` - Burn annotations into pages
- `.saveTextFromOCROption` - Save OCR text

### Test Image Behavior

Synthetic test images (solid colors, gradients) may produce **larger** files with JPEG due to how JPEG handles sharp edges. Real scanned documents with photographic noise compress well (3x reduction verified).

## Files Changed

- `DocboxKit/PDFGenerator.swift` - Added `compressImages` parameter and two-stage write
- `docbox/DocboxCommand.swift` - Added `--no-compress` flag
- `DocboxKitTests/PDFGeneratorTests.swift` - Added compression tests

## Tasks

- [x] Research PDFKit compression options
- [x] Implement two-stage write with PDFDocumentWriteOption
- [x] Add `--no-compress` CLI flag
- [x] Write tests for compression
- [x] Verify with real scanned documents (3x reduction)
