# docbox

A macOS command-line tool for scanning documents to searchable PDFs.

## Features

- Scanner discovery (USB, network, Bonjour, shared)
- Document feeder and flatbed support
- Configurable resolution, color mode, and page size
- Duplex scanning support
- OCR text recognition for searchable PDFs
- Automatic page orientation detection and correction

## Installation

### From Release (Recommended)

1. Download the latest `docbox-macos.zip` from [Releases](https://github.com/galexy/docbox/releases)
2. Extract the zip file
3. Run the install script:
   ```bash
   cd docbox-macos
   ./install.sh
   ```

This installs `docbox` to `/usr/local/bin`.

### Manual Installation

1. Download and extract the release zip
2. Copy the binary to your PATH:
   ```bash
   sudo cp docbox /usr/local/bin/
   sudo chmod +x /usr/local/bin/docbox
   ```

### From Source

See [Building](#building) below.

## Building

**Important:** Always specify `-scheme` when building. Building without a scheme fails because Swift Package Manager dependencies aren't resolved to the local build directory.

```bash
# Build (Debug)
xcodebuild build -scheme docbox

# Build (Release)
xcodebuild build -scheme docbox -configuration Release

# Run tests
xcodebuild test -scheme DocboxKit -destination 'platform=macOS'
```

## Usage

```bash
# List available scanners
docbox list

# Scan to PDF (recommended - creates searchable PDF with OCR)
docbox scan output.pdf

# Scan to multi-page TIFF
docbox scan output.tiff

# Scan to PNG (separate files: output.png, output-2.png, ...)
docbox scan output.png

# Scan with options
docbox scan --resolution 300 --grayscale --page-size letter output.pdf

# Skip OCR (faster, but PDF won't be searchable)
docbox scan --no-ocr output.pdf

# See all options
docbox scan --help
```

## Requirements

- macOS 14.0+
- Xcode 15+

## License

MIT
