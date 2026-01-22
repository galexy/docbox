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

## Workflow

When working on a story (or phase of the work). Remember to the following:

0. If a github issue isn't provided, create one for the scope of work (story)
   and create a new branch that will be used for the PR later.
1. Review the design document for high-level design
2. Write the detailed story design document and add to the stories folder.
3. Add the tasks you will work on to the gh issue. These should include the 
   unit tests and integration tests.
4. Work through the implementation and verify along the way by building and
   continuing to run tests.
5. Before moving the next phase or story, tell me you are done, commit your work
   thus far so that I can provide feedback and guide you if you things need to
   be updated. If there are issues, make sure to note that in the github issue
   as we work. As we fix each issue, add a commit once tests are passing and
   the issue is fixed.
6. When I'm satisified, created a PR. Make sure to include examples uses of
   the app (command line options, etc) to exercise the change or if the app
   has a UI, add screenshots and a walkthrough.
