import Foundation
import CoreGraphics
import ImageCaptureCore

/// Protocol for band data received from scanner
public protocol BandDataProtocol {
    var fullImageWidth: Int { get }
    var fullImageHeight: Int { get }
    var bitsPerPixel: Int { get }
    var bitsPerComponent: Int { get }
    var bytesPerRow: Int { get }
    var dataStartRow: Int { get }
    var dataNumRows: Int { get }
    var dataBuffer: Data? { get }
}

/// Make ICScannerBandData conform to our protocol
/// ICScannerBandData already has all the required properties
extension ICScannerBandData: BandDataProtocol {}

/// Assembles scan bands into a complete CGImage
public final class BandAssembler {
    private var buffer: UnsafeMutableRawPointer?
    private var width: Int = 0
    private var height: Int = 0
    private var bytesPerRow: Int = 0
    private var bitsPerComponent: Int = 0
    private var bitsPerPixel: Int = 0
    private var colorSpace: CGColorSpace?
    private var bitmapInfo: CGBitmapInfo = []
    private var isInitialized: Bool = false

    public init() {}

    deinit {
        reset()
    }

    /// Receive a band of scan data
    public func receiveBand(_ data: BandDataProtocol) {
        // Initialize buffer on first band
        if !isInitialized {
            initializeBuffer(from: data)
        }

        // Copy band data to buffer
        guard let buffer = buffer,
              let bandData = data.dataBuffer else {
            return
        }

        let offset = data.dataStartRow * bytesPerRow
        let bandSize = data.dataNumRows * bytesPerRow

        bandData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            let copySize = min(bandSize, rawBuffer.count)
            memcpy(buffer.advanced(by: offset), baseAddress, copySize)
        }
    }

    /// Assemble the complete image from received bands
    public func assembleImage() -> CGImage? {
        guard isInitialized,
              let buffer = buffer,
              let colorSpace = colorSpace else {
            return nil
        }

        let totalBytes = height * bytesPerRow

        guard let dataProvider = CGDataProvider(dataInfo: nil,
                                                 data: buffer,
                                                 size: totalBytes,
                                                 releaseData: { _, _, _ in }) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Reset the assembler for reuse
    public func reset() {
        if let buffer = buffer {
            buffer.deallocate()
            self.buffer = nil
        }
        width = 0
        height = 0
        bytesPerRow = 0
        bitsPerComponent = 0
        bitsPerPixel = 0
        colorSpace = nil
        bitmapInfo = []
        isInitialized = false
    }

    // MARK: - Private

    private func initializeBuffer(from data: BandDataProtocol) {
        width = data.fullImageWidth
        height = data.fullImageHeight
        bytesPerRow = data.bytesPerRow
        bitsPerComponent = data.bitsPerComponent
        bitsPerPixel = data.bitsPerPixel

        // Determine color space and bitmap info based on pixel format
        switch bitsPerPixel {
        case 1:
            // Monochrome 1-bit
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = []
        case 8:
            // Grayscale 8-bit
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = []
        case 24:
            // RGB 8-bit per component
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        case 32:
            // RGBA 8-bit per component
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        default:
            // Default to RGB
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        }

        // Allocate buffer
        let totalBytes = height * bytesPerRow
        buffer = UnsafeMutableRawPointer.allocate(byteCount: totalBytes, alignment: 8)
        buffer?.initializeMemory(as: UInt8.self, repeating: 0, count: totalBytes)

        isInitialized = true
    }
}
