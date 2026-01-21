# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

docbox is a macOS command-line tool written in Swift. The project is in early development stages.

## Build Commands

```bash
# Build with Xcode (Release)
xcodebuild -project docbox.xcodeproj -scheme docbox -configuration Release build

# Build with Xcode (Debug)
xcodebuild -project docbox.xcodeproj -scheme docbox -configuration Debug build

# Run the built executable (after building)
./build/Release/docbox
```

## Project Structure

- `docbox/` - Main source directory containing Swift source files
- `docbox.xcodeproj/` - Xcode project configuration

## Technical Details

- **Language:** Swift 6
- **Platform:** macOS 14.0+
- **Build System:** Xcode (no Swift Package Manager)
- **Product Type:** Command-line tool
