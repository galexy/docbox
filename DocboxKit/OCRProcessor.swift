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

    public init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
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
                        confidence: candidate.confidence
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
