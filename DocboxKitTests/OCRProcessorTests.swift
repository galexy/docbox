import Testing
import Foundation
import CoreGraphics
import CoreText
@testable import DocboxKit

@Suite("OCRProcessor Tests")
struct OCRProcessorTests {

    // MARK: - Helper

    /// Create a test image with text rendered on it
    private func createImageWithText(_ text: String, width: Int = 400, height: Int = 100) -> CGImage {
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

        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw text in black
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 36, nil)
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]
        let attributedString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributedString)

        context.textPosition = CGPoint(x: 20, y: 30)
        CTLineDraw(line, context)

        return context.makeImage()!
    }

    /// Create an empty white image
    private func createEmptyImage(width: Int = 400, height: Int = 100) -> CGImage {
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

        // Fill with white
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()!
    }

    // MARK: - Task 1.1: TextObservation initialization and properties

    @Test("TextObservation initialization and properties")
    func textObservationInitialization() {
        let observation = TextObservation(
            text: "Hello",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1),
            confidence: 0.95
        )

        #expect(observation.text == "Hello")
        #expect(observation.boundingBox.origin.x == 0.1)
        #expect(observation.boundingBox.origin.y == 0.2)
        #expect(observation.boundingBox.width == 0.5)
        #expect(observation.boundingBox.height == 0.1)
        #expect(observation.confidence == 0.95)
    }

    // MARK: - Task 1.2: Bounding box normalization validation

    @Test("bounding box normalization validation")
    func boundingBoxNormalization() {
        // Valid normalized coordinates (0.0-1.0)
        let observation = TextObservation(
            text: "Test",
            boundingBox: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0),
            confidence: 1.0
        )

        // Bounding box should be within 0.0-1.0 range
        #expect(observation.boundingBox.minX >= 0.0)
        #expect(observation.boundingBox.minY >= 0.0)
        #expect(observation.boundingBox.maxX <= 1.0)
        #expect(observation.boundingBox.maxY <= 1.0)
    }

    // MARK: - Task 2.2: Empty image returns empty observations

    @Test("empty image returns empty observations")
    func emptyImageReturnsEmpty() async throws {
        let processor = OCRProcessor(recognitionLevel: .fast)
        let emptyImage = createEmptyImage()

        let observations = try await processor.recognize(emptyImage)
        #expect(observations.isEmpty)
    }

    // MARK: - Task 2.3: Recognition level configuration

    @Test("recognition level configuration - fast")
    func recognitionLevelFast() async throws {
        let processor = OCRProcessor(recognitionLevel: .fast)
        // Verify it can be instantiated and used with fast level
        let emptyImage = createEmptyImage()
        let observations = try await processor.recognize(emptyImage)
        #expect(observations.isEmpty)
    }

    @Test("recognition level configuration - accurate")
    func recognitionLevelAccurate() async throws {
        let processor = OCRProcessor(recognitionLevel: .accurate)
        // Verify it can be instantiated and used with accurate level
        let emptyImage = createEmptyImage()
        let observations = try await processor.recognize(emptyImage)
        #expect(observations.isEmpty)
    }

    // MARK: - Task 2.1: Recognize text in image with known content

    @Test("recognize text in image with known content")
    func recognizeTextInImage() async throws {
        let processor = OCRProcessor(recognitionLevel: .accurate)
        let image = createImageWithText("HELLO")

        let observations = try await processor.recognize(image)

        // Should find at least one text observation
        #expect(!observations.isEmpty)

        // Should contain "HELLO" or similar (OCR might not be exact)
        let foundText = observations.map { $0.text.uppercased() }.joined(separator: " ")
        #expect(foundText.contains("HELLO") || foundText.contains("HELL") || foundText.contains("ELLO"))
    }

    // MARK: - Task 2.4: Bounding boxes are normalized (0.0-1.0)

    @Test("bounding boxes are normalized")
    func boundingBoxesNormalized() async throws {
        let processor = OCRProcessor(recognitionLevel: .accurate)
        let image = createImageWithText("TEST")

        let observations = try await processor.recognize(image)

        for observation in observations {
            // All bounding box coordinates should be normalized (0.0-1.0)
            #expect(observation.boundingBox.origin.x >= 0.0)
            #expect(observation.boundingBox.origin.y >= 0.0)
            #expect(observation.boundingBox.maxX <= 1.0)
            #expect(observation.boundingBox.maxY <= 1.0)
            #expect(observation.boundingBox.width > 0.0)
            #expect(observation.boundingBox.height > 0.0)
        }
    }

    // MARK: - TextObservation Equatable

    @Test("TextObservation equatable conformance")
    func textObservationEquatable() {
        let obs1 = TextObservation(
            text: "Hello",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1),
            confidence: 0.95
        )

        let obs2 = TextObservation(
            text: "Hello",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1),
            confidence: 0.95
        )

        let obs3 = TextObservation(
            text: "World",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1),
            confidence: 0.95
        )

        #expect(obs1 == obs2)
        #expect(obs1 != obs3)
    }

    // MARK: - TextObservation corner points

    @Test("TextObservation has corner points")
    func textObservationCornerPoints() {
        let observation = TextObservation(
            text: "Test",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1),
            confidence: 0.95,
            topLeft: CGPoint(x: 0.1, y: 0.3),
            topRight: CGPoint(x: 0.6, y: 0.3),
            bottomLeft: CGPoint(x: 0.1, y: 0.2),
            bottomRight: CGPoint(x: 0.6, y: 0.2)
        )

        #expect(observation.topLeft == CGPoint(x: 0.1, y: 0.3))
        #expect(observation.topRight == CGPoint(x: 0.6, y: 0.3))
        #expect(observation.bottomLeft == CGPoint(x: 0.1, y: 0.2))
        #expect(observation.bottomRight == CGPoint(x: 0.6, y: 0.2))
    }
}

// MARK: - OrientationDetector Tests

@Suite("OrientationDetector Tests")
struct OrientationDetectorTests {

    /// Create observation with specific text angle (in degrees)
    private func createObservation(angle: CGFloat) -> TextObservation {
        let radians = angle * .pi / 180
        let length: CGFloat = 0.5

        // Create corner points based on angle
        let topLeft = CGPoint(x: 0.2, y: 0.5)
        let topRight = CGPoint(
            x: topLeft.x + length * cos(radians),
            y: topLeft.y + length * sin(radians)
        )
        let bottomLeft = CGPoint(
            x: topLeft.x - 0.05 * sin(radians),
            y: topLeft.y + 0.05 * cos(radians)
        )
        let bottomRight = CGPoint(
            x: topRight.x - 0.05 * sin(radians),
            y: topRight.y + 0.05 * cos(radians)
        )

        return TextObservation(
            text: "Test",
            boundingBox: CGRect(x: 0.2, y: 0.45, width: 0.5, height: 0.1),
            confidence: 0.95,
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        )
    }

    @Test("detect upright orientation (0°)")
    func detectUprightOrientation() {
        let observations = [
            createObservation(angle: 0),
            createObservation(angle: 5),
            createObservation(angle: -5)
        ]

        let orientation = OrientationDetector.detect(from: observations)
        #expect(orientation == .up)
    }

    @Test("detect right rotation (90°)")
    func detectRightRotation() {
        let observations = [
            createObservation(angle: 90),
            createObservation(angle: 85),
            createObservation(angle: 95)
        ]

        let orientation = OrientationDetector.detect(from: observations)
        #expect(orientation == .right)
    }

    @Test("detect upside down (180°)")
    func detectUpsideDown() {
        let observations = [
            createObservation(angle: 180),
            createObservation(angle: 175),
            createObservation(angle: -175)
        ]

        let orientation = OrientationDetector.detect(from: observations)
        #expect(orientation == .down)
    }

    @Test("detect left rotation (270°)")
    func detectLeftRotation() {
        let observations = [
            createObservation(angle: 270),
            createObservation(angle: -90),
            createObservation(angle: 265)
        ]

        let orientation = OrientationDetector.detect(from: observations)
        #expect(orientation == .left)
    }

    @Test("empty observations defaults to up")
    func emptyObservationsDefaultsToUp() {
        let orientation = OrientationDetector.detect(from: [])
        #expect(orientation == .up)
    }

    @Test("mixed angles uses majority")
    func mixedAnglesUsesMajority() {
        // 3 upright, 1 rotated
        let observations = [
            createObservation(angle: 0),
            createObservation(angle: 5),
            createObservation(angle: -5),
            createObservation(angle: 90)
        ]

        let orientation = OrientationDetector.detect(from: observations)
        #expect(orientation == .up)
    }

    @Test("correction degrees are correct")
    func correctionDegreesCorrect() {
        #expect(PageOrientation.up.correctionDegrees == 0)
        #expect(PageOrientation.right.correctionDegrees == 270)
        #expect(PageOrientation.down.correctionDegrees == 180)
        #expect(PageOrientation.left.correctionDegrees == 90)
    }
}

// MARK: - CGImage Rotation Tests

@Suite("CGImage Rotation Tests")
struct CGImageRotationTests {

    /// Create a test image with specific dimensions
    private func createTestImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

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

    @Test("rotate 90° produces correct dimensions")
    func rotate90ProducesCorrectDimensions() {
        let image = createTestImage(width: 400, height: 100)
        let rotated = image.rotated(by: 90)

        #expect(rotated != nil)
        #expect(rotated?.width == 100)
        #expect(rotated?.height == 400)
    }

    @Test("rotate 180° preserves dimensions")
    func rotate180PreservesDimensions() {
        let image = createTestImage(width: 400, height: 100)
        let rotated = image.rotated(by: 180)

        #expect(rotated != nil)
        #expect(rotated?.width == 400)
        #expect(rotated?.height == 100)
    }

    @Test("rotate 270° produces correct dimensions")
    func rotate270ProducesCorrectDimensions() {
        let image = createTestImage(width: 400, height: 100)
        let rotated = image.rotated(by: 270)

        #expect(rotated != nil)
        #expect(rotated?.width == 100)
        #expect(rotated?.height == 400)
    }

    @Test("rotate 0° returns original")
    func rotate0ReturnsOriginal() {
        let image = createTestImage(width: 400, height: 100)
        let rotated = image.rotated(by: 0)

        #expect(rotated != nil)
        #expect(rotated?.width == 400)
        #expect(rotated?.height == 100)
    }

    @Test("invalid rotation returns nil")
    func invalidRotationReturnsNil() {
        let image = createTestImage(width: 400, height: 100)
        let rotated = image.rotated(by: 45)

        #expect(rotated == nil)
    }
}
