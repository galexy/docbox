# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

docbox is a macOS command-line tool that scans physical documents, performs OCR, and generates searchable PDF files. It uses ImageCaptureCore for scanner access, Vision for OCR, and PDFKit for PDF generation.

## Build Commands

**Important:** Always specify `-scheme` when building. Building without a scheme fails because Swift Package Manager dependencies (ArgumentParser) aren't resolved to the local build directory.

```bash
# Build the CLI (Debug)
xcodebuild build -scheme docbox

# Build the CLI (Release)
xcodebuild build -scheme docbox -configuration Release

# Build the framework
xcodebuild build -scheme DocboxKit

# Run tests
xcodebuild test -scheme DocboxKit -destination 'platform=macOS'

# Run the built executable
./build/Debug/docbox list
./build/Debug/docbox scan --help
```

## Project Structure

- `docbox/` - CLI application using Swift Argument Parser
- `DocboxKit/` - Core framework with scanner management and image processing
- `DocboxKitTests/` - Unit and integration tests
- `stories/` - Development story documents with detailed design and tasks
- `DESIGN.md` - Architecture and design documentation

## Technical Details

- **Language:** Swift 6
- **Platform:** macOS 14.0+
- **Build System:** Xcode with Swift Package Manager
- **Dependencies:** swift-argument-parser 1.7.0
- **Product Type:** Command-line tool + Framework

## Key Classes

- `ScannerManager` - Handles scanner discovery and scanning operations
- `BandAssembler` - Assembles scan bands into CGImage
- `ScanConfiguration` - Value type for scan parameters
