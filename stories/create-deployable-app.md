# Create Deployable App

**Date:** 2026-01-21
**Branch:** `create-deployable-app`
**Issue:** https://github.com/galexy/docbox/issues/8

## Overview

Create a GitHub Actions workflow to build the docbox CLI and provide a way to install it on macOS.

## Deliverables

- GitHub Actions workflow for building releases
- Distributable zip artifact with the CLI binary
- Installation script for easy setup
- Updated README with installation instructions

## Detailed Design

### GitHub Actions Workflow

Create `.github/workflows/build.yml` that:

1. Triggers on:
   - Push to main branch
   - Pull requests to main
   - Manual workflow dispatch
   - Release tags (v*)

2. Build steps:
   - Checkout code
   - Build with xcodebuild (Release configuration)
   - Sign the binary (ad-hoc for now)
   - Create zip artifact with binary and install script
   - Upload artifact

3. Release steps (on tag):
   - Create GitHub Release
   - Attach zip artifact

### Installation

Two installation methods:

1. **Manual installation:**
   - Download release zip
   - Extract and run install script
   - Or manually copy binary to /usr/local/bin

2. **Install script:**
   - Copy docbox binary to /usr/local/bin
   - Set executable permissions
   - Verify installation

### Binary Location

The built binary will be at:
```
DerivedData/Build/Products/Release/docbox
```

Or use `xcodebuild -showBuildSettings` to find BUILT_PRODUCTS_DIR.

## Tasks

### Implementation

#### 1. GitHub Actions Workflow
- [x] 1.1 Create .github/workflows directory
- [x] 1.2 Create build.yml workflow file
- [x] 1.3 Add build job for macOS
- [x] 1.4 Add artifact upload step
- [x] 1.5 Add release job for tags

#### 2. Installation Script
- [x] 2.1 Create install.sh script
- [x] 2.2 Handle /usr/local/bin creation if needed
- [x] 2.3 Copy binary and set permissions
- [x] 2.4 Print success message

#### 3. Documentation
- [x] 3.1 Update README with installation instructions
- [x] 3.2 Document manual installation steps
- [x] 3.3 Document build from source instructions
