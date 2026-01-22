import Foundation
import CoreGraphics
import Vision

/// Represents recognized text with its position in the image
public struct TextObservation: Equatable, Sendable {
    /// The recognized text string
    public let text: String

    /// Bounding box in normalized coordinates (0.0-1.0), bottom-left origin
    public let boundingBox: CGRect

    /// Recognition confidence (0.0-1.0)
    public let confidence: Float

    /// Corner points in normalized coordinates (0.0-1.0), bottom-left origin
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomLeft: CGPoint
    public let bottomRight: CGPoint

    public init(text: String, boundingBox: CGRect, confidence: Float,
                topLeft: CGPoint = .zero, topRight: CGPoint = .zero,
                bottomLeft: CGPoint = .zero, bottomRight: CGPoint = .zero) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

/// Page orientation based on text angle analysis
public enum PageOrientation: Int, Sendable {
    case up = 0        // Correct orientation
    case right = 90    // Rotated 90° clockwise
    case down = 180    // Upside down
    case left = 270    // Rotated 90° counter-clockwise

    /// The rotation needed to correct this orientation (opposite direction)
    public var correctionDegrees: Int {
        switch self {
        case .up: return 0
        case .right: return 270  // Rotate 270° CW (or 90° CCW) to fix
        case .down: return 180
        case .left: return 90    // Rotate 90° CW to fix
        }
    }
}

/// Detects page orientation from text observations
public struct OrientationDetector {
    /// Detect page orientation from text observations by analyzing text angles
    /// - Parameter observations: Array of text observations with corner points
    /// - Returns: Detected page orientation
    public static func detect(from observations: [TextObservation]) -> PageOrientation {
        guard !observations.isEmpty else {
            return .up
        }

        var angleCounts: [PageOrientation: Int] = [.up: 0, .right: 0, .down: 0, .left: 0]

        for observation in observations {
            // Calculate angle from topLeft to topRight (the text baseline direction)
            let dx = observation.topRight.x - observation.topLeft.x
            let dy = observation.topRight.y - observation.topLeft.y
            var angle = atan2(dy, dx) * 180 / .pi

            // Normalize to 0-360 range
            if angle < 0 {
                angle += 360
            }

            // Bucket into quadrants
            let orientation: PageOrientation
            if angle >= 315 || angle < 45 {
                orientation = .up
            } else if angle >= 45 && angle < 135 {
                orientation = .right
            } else if angle >= 135 && angle < 225 {
                orientation = .down
            } else {
                orientation = .left
            }

            angleCounts[orientation, default: 0] += 1
        }

        // Return the most common orientation
        return angleCounts.max(by: { $0.value < $1.value })?.key ?? .up
    }
}

/// Extension to rotate CGImage
public extension CGImage {
    /// Rotate image by specified degrees (must be 0, 90, 180, or 270)
    /// - Parameter degrees: Rotation in degrees (0, 90, 180, or 270)
    /// - Returns: Rotated image, or nil if rotation fails
    func rotated(by degrees: Int) -> CGImage? {
        guard degrees != 0 else { return self }

        let radians = CGFloat(degrees) * .pi / 180

        // Calculate new dimensions
        let originalWidth = CGFloat(width)
        let originalHeight = CGFloat(height)

        let newWidth: Int
        let newHeight: Int

        switch degrees {
        case 90, 270:
            newWidth = height
            newHeight = width
        case 180:
            newWidth = width
            newHeight = height
        default:
            return nil // Only support 90° increments
        }

        // Create context with new dimensions
        guard let colorSpace = self.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        // Move origin and rotate
        switch degrees {
        case 90:
            context.translateBy(x: CGFloat(newWidth), y: 0)
        case 180:
            context.translateBy(x: CGFloat(newWidth), y: CGFloat(newHeight))
        case 270:
            context.translateBy(x: 0, y: CGFloat(newHeight))
        default:
            break
        }

        context.rotate(by: radians)

        // Draw the original image
        context.draw(self, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))

        return context.makeImage()
    }
}

/// Performs optical character recognition on images using Vision framework
public final class OCRProcessor {
    /// Recognition accuracy level
    public enum RecognitionLevel {
        case fast
        case accurate

        var visionLevel: VNRequestTextRecognitionLevel {
            switch self {
            case .fast: return .fast
            case .accurate: return .accurate
            }
        }
    }

    private let recognitionLevel: RecognitionLevel

    /// Creates an OCRProcessor with the specified recognition level
    /// - Parameter recognitionLevel: The accuracy level for text recognition (default: .accurate)
    public init(recognitionLevel: RecognitionLevel = .accurate) {
        self.recognitionLevel = recognitionLevel
    }

    /// Recognize text in an image
    /// - Parameter image: The image to process
    /// - Returns: Array of text observations with positions and confidence
    public func recognize(_ image: CGImage) async throws -> [TextObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let textObservations = observations.compactMap { observation -> TextObservation? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    return TextObservation(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence,
                        topLeft: observation.topLeft,
                        topRight: observation.topRight,
                        bottomLeft: observation.bottomLeft,
                        bottomRight: observation.bottomRight
                    )
                }

                continuation.resume(returning: textObservations)
            }

            request.recognitionLevel = recognitionLevel.visionLevel
            request.usesLanguageCorrection = true

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    /// Recognize text with automatic orientation detection and correction
    /// - Parameter image: The image to process
    /// - Returns: Tuple of corrected image and text observations
    public func recognizeWithOrientationCorrection(_ image: CGImage) async throws -> (image: CGImage, observations: [TextObservation]) {
        // First pass: recognize text to detect orientation
        let initialObservations = try await recognize(image)

        // Detect orientation from text angles
        let orientation = OrientationDetector.detect(from: initialObservations)

        // If already upright, return original results
        guard orientation != .up else {
            return (image, initialObservations)
        }

        // Rotate image to correct orientation
        guard let rotatedImage = image.rotated(by: orientation.correctionDegrees) else {
            // If rotation fails, return original
            return (image, initialObservations)
        }

        // Second pass: recognize text on corrected image
        let correctedObservations = try await recognize(rotatedImage)

        return (rotatedImage, correctedObservations)
    }
}

/// Errors that can occur during OCR processing
public enum OCRError: Error, LocalizedError {
    case recognitionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .recognitionFailed(let error):
            return "OCR recognition failed: \(error.localizedDescription)"
        }
    }
}
