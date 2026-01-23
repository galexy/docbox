#!/bin/bash
#
# docbox installer
# Installs docbox CLI to /usr/local/bin
#

set -e

INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/docbox"

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: docbox binary not found at $BINARY"
    echo "Make sure you're running this script from the extracted zip directory."
    exit 1
fi

# Create install directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Creating $INSTALL_DIR..."
    sudo mkdir -p "$INSTALL_DIR"
fi

# Copy binary
echo "Installing docbox to $INSTALL_DIR..."
sudo cp "$BINARY" "$INSTALL_DIR/docbox"
sudo chmod +x "$INSTALL_DIR/docbox"

# Verify installation
if command -v docbox &> /dev/null; then
    echo ""
    echo "docbox installed successfully!"
    echo ""
    docbox --help
else
    echo ""
    echo "docbox installed to $INSTALL_DIR/docbox"
    echo "You may need to add $INSTALL_DIR to your PATH."
    echo ""
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi
