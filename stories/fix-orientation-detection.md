# Fix: Orientation Detection for OCR

**Date:** 2026-01-21
**Branch:** `fix-orientation-detection`
**Issue:** https://github.com/galexy/docbox/issues/6

## Overview

Fix OCR text extraction for pages scanned in landscape orientation (rotated 90° left or right). Currently, rotated pages produce incomplete or incorrect OCR results.

## Problem

When a page is scanned rotated 90° (landscape orientation), the Vision framework's OCR cannot properly recognize text because it expects upright text. The resulting PDF has incomplete searchable text.

## Solution

Implement orientation detection using VNRecognizedTextObservation corner points, then rotate the image before final OCR and PDF output.

### Approach

1. Run initial OCR pass
2. Analyze text observation corner points to detect dominant text angle
3. If rotation detected (>45° from horizontal), determine nearest 90° rotation
4. Rotate the CGImage to correct orientation
5. Re-run OCR on rotated image
6. Output correctly-oriented image and text to PDF

## Deliverables

- `OrientationDetector` class to analyze text observations and detect page rotation
- `CGImage` rotation extension
- Updated `OCRProcessor` to optionally detect and correct orientation
- Updated CLI pipeline to use orientation correction for PDF output

## Detailed Design

### OrientationDetector

Analyzes text observations to determine page orientation:

```swift
public enum PageOrientation: Int {
    case up = 0        // 0° - correct orientation
    case right = 90    // 90° CW - rotated right
    case down = 180    // 180° - upside down
    case left = 270    // 270° CW (90° CCW) - rotated left
}

public struct OrientationDetector {
    /// Detect page orientation from text observations
    static func detect(from observations: [TextObservation]) -> PageOrientation
}
```

Algorithm:
1. For each observation, calculate angle from topLeft to topRight corner
2. Normalize angles to 0-360° range
3. Bucket angles into quadrants (0°, 90°, 180°, 270°)
4. Return most common orientation

### CGImage Rotation Extension

```swift
extension CGImage {
    /// Rotate image by specified degrees (must be 0, 90, 180, or 270)
    func rotated(by degrees: Int) -> CGImage?
}
```

### Updated TextObservation

Add corner points to TextObservation:

```swift
public struct TextObservation {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
    // New: corner points for orientation detection
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomLeft: CGPoint
    public let bottomRight: CGPoint
}
```

### OCRProcessor Updates

Add orientation-aware recognition:

```swift
public func recognizeWithOrientationCorrection(_ image: CGImage) async throws -> (image: CGImage, observations: [TextObservation])
```

This method:
1. Runs initial OCR
2. Detects orientation from observations
3. If rotated, rotates image and re-runs OCR
4. Returns corrected image and observations

## Tasks

### Unit Tests

#### 1. OrientationDetector Tests
- [x] 1.1 Detect upright orientation (0°)
- [x] 1.2 Detect right rotation (90°)
- [x] 1.3 Detect upside down (180°)
- [x] 1.4 Detect left rotation (270°)
- [x] 1.5 Handle empty observations (default to up)
- [x] 1.6 Handle mixed angles (use majority)

#### 2. CGImage Rotation Tests
- [x] 2.1 Rotate 90° produces correct dimensions
- [x] 2.2 Rotate 180° preserves dimensions
- [x] 2.3 Rotate 270° produces correct dimensions
- [x] 2.4 Rotate 0° returns original

#### 3. Integration Tests
- [x] 3.1 OCR with orientation correction improves rotated text recognition
- [x] 3.2 PDF output has correct orientation

### Implementation

#### 4. TextObservation Updates
- [x] 4.1 Add corner point properties
- [x] 4.2 Update OCRProcessor to extract corner points

#### 5. OrientationDetector
- [x] 5.1 Create OrientationDetector struct
- [x] 5.2 Implement angle calculation from corners
- [x] 5.3 Implement orientation bucketing

#### 6. CGImage Rotation
- [x] 6.1 Create CGImage rotation extension
- [x] 6.2 Implement 90°, 180°, 270° rotations

#### 7. OCRProcessor Updates
- [x] 7.1 Add recognizeWithOrientationCorrection method
- [x] 7.2 Integrate orientation detection and image rotation

#### 8. CLI Updates
- [x] 8.1 Use orientation-corrected OCR for PDF output
- [x] 8.2 Add --no-orientation flag to skip detection
