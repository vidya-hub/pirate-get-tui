#!/bin/bash
#
# Build macOS release for pirate-get
# Creates a standalone package with all dependencies
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION=$(python3 -c "import sys; sys.path.insert(0, '$PROJECT_ROOT'); from pirate.data import version; print(version)")
PACKAGE_NAME="pirate-get"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Building $PACKAGE_NAME $VERSION for macOS${NC}"

# Build directories
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$SCRIPT_DIR/dist"
APP_DIR="$BUILD_DIR/$PACKAGE_NAME-$VERSION-macos"

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR"
mkdir -p "$OUTPUT_DIR"

# Create virtual environment for standalone package
echo "Creating virtual environment..."
python3 -m venv "$APP_DIR/venv"
source "$APP_DIR/venv/bin/activate"

# Install the package
echo "Installing pirate-get and dependencies..."
pip install --upgrade pip
pip install "$PROJECT_ROOT"

# Create wrapper scripts
mkdir -p "$APP_DIR/bin"

cat > "$APP_DIR/bin/pirate-get" << 'WRAPPER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../venv/bin/activate"
python -m pirate.pirate "$@"
WRAPPER
chmod +x "$APP_DIR/bin/pirate-get"

cat > "$APP_DIR/bin/pirate-get-tui" << 'WRAPPER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../venv/bin/activate"
python -m pirate.tui "$@"
WRAPPER
chmod +x "$APP_DIR/bin/pirate-get-tui"

# Create install script
cat > "$APP_DIR/install.sh" << 'INSTALL'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${1:-/usr/local/opt/pirate-get}"

echo "Installing pirate-get to $INSTALL_DIR..."

# Create installation directory
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"

# Create symlinks in /usr/local/bin
sudo ln -sf "$INSTALL_DIR/bin/pirate-get" /usr/local/bin/pirate-get
sudo ln -sf "$INSTALL_DIR/bin/pirate-get-tui" /usr/local/bin/pirate-get-tui

echo "Installation complete!"
echo "Run 'pirate-get --help' to get started"
INSTALL
chmod +x "$APP_DIR/install.sh"

# Create uninstall script
cat > "$APP_DIR/uninstall.sh" << 'UNINSTALL'
#!/bin/bash
set -e

INSTALL_DIR="${1:-/usr/local/opt/pirate-get}"

echo "Uninstalling pirate-get..."

sudo rm -f /usr/local/bin/pirate-get
sudo rm -f /usr/local/bin/pirate-get-tui
sudo rm -rf "$INSTALL_DIR"

echo "Uninstallation complete!"
UNINSTALL
chmod +x "$APP_DIR/uninstall.sh"

# Create README
cat > "$APP_DIR/README.txt" << README
pirate-get $VERSION for macOS
==============================

Installation:
  ./install.sh

This will install pirate-get to /usr/local/opt/pirate-get
and create symlinks in /usr/local/bin.

Alternatively, install via Homebrew:
  brew install --build-from-source pirate-get.rb

Usage:
  pirate-get "search term"     # Search torrents
  pirate-get --tui             # Interactive TUI mode
  pirate-get -h                # Show help

Uninstallation:
  ./uninstall.sh

Requirements:
  - macOS 10.15 or later
  - Python 3.8+ (included in package)
README

deactivate

# Create tarball
echo "Creating tarball..."
cd "$BUILD_DIR"
tar -czvf "$OUTPUT_DIR/$PACKAGE_NAME-$VERSION-macos.tar.gz" "$PACKAGE_NAME-$VERSION-macos"

# Create DMG (if hdiutil available)
if command -v hdiutil &> /dev/null; then
    echo "Creating DMG..."
    hdiutil create -volname "$PACKAGE_NAME-$VERSION" \
        -srcfolder "$APP_DIR" \
        -ov -format UDZO \
        "$OUTPUT_DIR/$PACKAGE_NAME-$VERSION-macos.dmg"
fi

echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "Output files:"
ls -la "$OUTPUT_DIR"

# Cleanup
rm -rf "$BUILD_DIR"

echo ""
echo "Installation instructions:"
echo "  tar -xzf $OUTPUT_DIR/$PACKAGE_NAME-$VERSION-macos.tar.gz"
echo "  cd $PACKAGE_NAME-$VERSION-macos"
echo "  ./install.sh"
