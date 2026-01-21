import Foundation
import ImageCaptureCore

/// Configuration for a scan operation
public struct ScanConfiguration {
    public var functionalUnitType: ICScannerFunctionalUnitType = .documentFeeder
    public var resolution: Int = 300
    public var colorMode: ColorMode = .color
    public var pageSize: PageSize = .letter
    public var duplex: Bool = false

    public init(
        functionalUnitType: ICScannerFunctionalUnitType = .documentFeeder,
        resolution: Int = 300,
        colorMode: ColorMode = .color,
        pageSize: PageSize = .letter,
        duplex: Bool = false
    ) {
        self.functionalUnitType = functionalUnitType
        self.resolution = resolution
        self.colorMode = colorMode
        self.pageSize = pageSize
        self.duplex = duplex
    }

    /// Color mode for scanning
    public enum ColorMode: String, CaseIterable {
        case color
        case grayscale
        case mono

        public var pixelDataType: ICScannerPixelDataType {
            switch self {
            case .color: return .RGB
            case .grayscale: return .gray
            case .mono: return .BW
            }
        }

        public var bitDepth: ICScannerBitDepth {
            switch self {
            case .color: return .depth8Bits
            case .grayscale: return .depth8Bits
            case .mono: return .depth1Bit
            }
        }
    }

    /// Standard page sizes for scanning
    public enum PageSize: String, CaseIterable {
        case letter
        case legal
        case a4

        public var documentType: ICScannerDocumentType {
            switch self {
            case .letter: return .typeUSLetter
            case .legal: return .typeUSLegal
            case .a4: return .typeA4
            }
        }

        /// Page dimensions in inches
        public var dimensions: (width: Double, height: Double) {
            switch self {
            case .letter: return (8.5, 11.0)
            case .legal: return (8.5, 14.0)
            case .a4: return (8.27, 11.69)  // 210mm x 297mm
            }
        }
    }
}
