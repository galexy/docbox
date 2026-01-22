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
}
