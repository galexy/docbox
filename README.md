# docbox

A macOS command-line tool for scanning documents to searchable PDFs.

## Features

- Scanner discovery (USB, network, Bonjour, shared)
- Document feeder and flatbed support
- Configurable resolution, color mode, and page size
- Duplex scanning support

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
./build/Debug/docbox list

# Scan a document
./build/Debug/docbox scan output.png

# Scan with options
./build/Debug/docbox scan --resolution 300 --grayscale --page-size letter output.png

# See all options
./build/Debug/docbox scan --help
```

## Requirements

- macOS 14.0+
- Xcode 15+

## License

MIT
