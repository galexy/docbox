//
//  DocboxCommand.swift
//  docbox
//
//  A command-line document scanner that produces searchable PDFs.
//

import Foundation
import ArgumentParser
import DocboxKit
import ImageCaptureCore
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@main
@available(macOS 10.15, *)
struct DocboxCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "docbox",
        abstract: "Scan documents to searchable PDFs",
        subcommands: [ListCommand.self, ScanCommand.self]
    )
}

// MARK: - Connection Type Filter

enum ConnectionFilter: String, ExpressibleByArgument, CaseIterable {
    case all
    case usb
    case network
    case shared
    case bluetooth

    func matches(deviceType: ICDeviceType) -> Bool {
        let rawValue = deviceType.rawValue
        switch self {
        case .all:
            return true
        case .usb:
            return rawValue & ICDeviceLocationTypeMask.local.rawValue != 0
        case .network:
            return rawValue & ICDeviceLocationTypeMask.bonjour.rawValue != 0
        case .shared:
            return rawValue & ICDeviceLocationTypeMask.shared.rawValue != 0
        case .bluetooth:
            return rawValue & ICDeviceLocationTypeMask.bluetooth.rawValue != 0
        }
    }

    static func connectionTypeString(for deviceType: ICDeviceType) -> String {
        let rawValue = deviceType.rawValue
        if rawValue & ICDeviceLocationTypeMask.local.rawValue != 0 {
            return "USB"
        } else if rawValue & ICDeviceLocationTypeMask.bonjour.rawValue != 0 {
            return "Network"
        } else if rawValue & ICDeviceLocationTypeMask.shared.rawValue != 0 {
            return "Shared"
        } else if rawValue & ICDeviceLocationTypeMask.bluetooth.rawValue != 0 {
            return "Bluetooth"
        } else {
            return "type:\(rawValue)"
        }
    }
}

// MARK: - List Command

@available(macOS 10.15, *)
struct ListCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available scanners"
    )

    @Option(name: .long, help: "Filter by connection type: all, usb, network, shared, bluetooth")
    var connection: ConnectionFilter = .all

    @Option(name: .long, help: "Discovery timeout in seconds")
    var timeout: Double = 2.0

    func run() async throws {
        let manager = ScannerManager()

        print("Discovering scanners...")
        let allScanners = await manager.discoverScanners(timeout: timeout)
        let scanners = allScanners.filter { connection.matches(deviceType: $0.deviceType) }

        if scanners.isEmpty {
            if connection == .all {
                print("No scanners found.")
            } else {
                print("No \(connection.rawValue) scanners found.")
            }
        } else {
            print("Found \(scanners.count) scanner(s):")
            for (index, scanner) in scanners.enumerated() {
                let connectionType = ConnectionFilter.connectionTypeString(for: scanner.deviceType)
                print("  \(index + 1). \(scanner.name) (\(connectionType))")
            }
        }
    }
}

// MARK: - Scan Command

@available(macOS 10.15, *)
struct ScanCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan documents"
    )

    @Option(name: .long, help: "Scanner name (partial match)")
    var scanner: String?

    @Option(name: .long, help: "Filter by connection type: all, usb, network, shared, bluetooth")
    var connection: ConnectionFilter = .all

    @Flag(name: .long, help: "Use flatbed instead of document feeder")
    var flatbed: Bool = false

    @Flag(name: .long, help: "Enable duplex scanning")
    var duplex: Bool = false

    @Option(name: .long, help: "Resolution in DPI")
    var resolution: Int = 300

    @Flag(name: .long, help: "Scan in color")
    var color: Bool = false

    @Flag(name: .long, help: "Scan in grayscale")
    var grayscale: Bool = false

    @Flag(name: .long, help: "Scan in black and white")
    var mono: Bool = false

    @Option(name: .long, help: "Page size: letter, legal, a4")
    var pageSize: String = "letter"

    @Option(name: .long, help: "Discovery timeout in seconds")
    var timeout: Double = 2.0

    @Argument(help: "Output file path (PNG format)")
    var output: String

    func run() async throws {
        // Determine color mode
        let colorMode: ScanConfiguration.ColorMode
        if color {
            colorMode = .color
        } else if grayscale {
            colorMode = .grayscale
        } else if mono {
            colorMode = .mono
        } else {
            colorMode = .grayscale  // Default to grayscale
        }

        // Determine page size
        guard let pageSizeEnum = ScanConfiguration.PageSize(rawValue: pageSize.lowercased()) else {
            throw ValidationError("Invalid page size '\(pageSize)'. Use: letter, legal, or a4")
        }

        // Create configuration
        let config = ScanConfiguration(
            functionalUnitType: flatbed ? .flatbed : .documentFeeder,
            resolution: resolution,
            colorMode: colorMode,
            pageSize: pageSizeEnum,
            duplex: duplex
        )

        // Discover scanners
        let manager = ScannerManager()
        print("Discovering scanners...")
        let allScanners = await manager.discoverScanners(timeout: timeout)
        let scanners = allScanners.filter { connection.matches(deviceType: $0.deviceType) }

        guard !scanners.isEmpty else {
            throw ScannerError.noScannersFound
        }

        // Select scanner
        let selectedScanner: any ScannerDeviceProtocol
        if let scannerName = scanner {
            guard let found = scanners.first(where: { $0.name.localizedCaseInsensitiveContains(scannerName) }) else {
                throw ScannerError.scannerNotFound(name: scannerName)
            }
            selectedScanner = found
        } else {
            selectedScanner = scanners[0]
        }

        let connectionType = ConnectionFilter.connectionTypeString(for: selectedScanner.deviceType)
        print("Using scanner: \(selectedScanner.name) (\(connectionType))")
        print("Configuration: \(resolution) DPI, \(colorMode), \(pageSizeEnum), duplex: \(duplex)")
        print("Scanning...")

        // Perform scan
        let stream = manager.scan(device: selectedScanner, config: config, timeout: 60.0)

        var pageCount = 0
        for await image in stream {
            pageCount += 1
            let pagePath = generatePagePath(basePath: output, pageNumber: pageCount)
            if saveImageAsPNG(image, to: pagePath) {
                print("Saved page \(pageCount) to: \(pagePath)")
            } else {
                print("Failed to save page \(pageCount)")
            }
        }

        if pageCount == 0 {
            print("No pages scanned.")
        } else {
            print("Scan complete. \(pageCount) page(s) saved.")
        }
    }

    /// Generate a page path, inserting page number before extension for multi-page scans
    private func generatePagePath(basePath: String, pageNumber: Int) -> String {
        let url = URL(fileURLWithPath: basePath)
        let ext = url.pathExtension
        let nameWithoutExt = url.deletingPathExtension().path

        if pageNumber == 1 {
            // First page uses the original filename
            return basePath
        } else {
            // Subsequent pages get numbered: output.png -> output-2.png
            return "\(nameWithoutExt)-\(pageNumber).\(ext)"
        }
    }
}

// MARK: - Image Saving

func saveImageAsPNG(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return false
    }

    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}
