#!/bin/bash
#
# Build Ubuntu/Debian .deb package for pirate-get
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION=$(python3 -c "import sys; sys.path.insert(0, '$PROJECT_ROOT'); from pirate.data import version; print(version)")
PACKAGE_NAME="pirate-get"
ARCH="all"  # Pure Python, architecture independent

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Building $PACKAGE_NAME $VERSION for Ubuntu/Debian${NC}"

# Build directory
BUILD_DIR="$SCRIPT_DIR/build"
PKG_DIR="$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$PKG_DIR"

# Create directory structure
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/lib/python3/dist-packages"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/doc/$PACKAGE_NAME"
mkdir -p "$PKG_DIR/usr/share/man/man1"

# Copy Python package
cp -r "$PROJECT_ROOT/pirate" "$PKG_DIR/usr/lib/python3/dist-packages/"

# Create wrapper scripts
cat > "$PKG_DIR/usr/bin/pirate-get" << 'EOF'
#!/usr/bin/env python3
from pirate.pirate import main
if __name__ == '__main__':
    main()
EOF
chmod +x "$PKG_DIR/usr/bin/pirate-get"

cat > "$PKG_DIR/usr/bin/pirate-get-tui" << 'EOF'
#!/usr/bin/env python3
from pirate.tui import main
if __name__ == '__main__':
    main()
EOF
chmod +x "$PKG_DIR/usr/bin/pirate-get-tui"

# Create control file
cat > "$PKG_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: net
Priority: optional
Architecture: $ARCH
Depends: python3 (>= 3.6), python3-colorama, python3-pip
Recommends: transmission-cli
Maintainer: pirate-get maintainers <pirate-get@example.com>
Homepage: https://github.com/vikstrous/pirate-get
Description: Command-line torrent search tool for The Pirate Bay
 pirate-get is a convenient command line tool to search and download
 torrents from The Pirate Bay. Features include:
  - Search torrents by keywords
  - Filter by category and sort options
  - Interactive TUI mode with Textual
  - Integration with transmission-remote
  - Magnet link and .torrent file support
EOF

# Create postinst script to install Python dependencies
cat > "$PKG_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Install Python dependencies not available in apt
pip3 install --quiet veryprettytable>=0.8.1 pyperclip>=1.6.2 textual>=1.0.0 2>/dev/null || true

echo "pirate-get installed successfully!"
echo "Run 'pirate-get --help' to get started"
echo "Run 'pirate-get --tui' for interactive mode"

exit 0
EOF
chmod +x "$PKG_DIR/DEBIAN/postinst"

# Create copyright file
cat > "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: pirate-get
Source: https://github.com/vikstrous/pirate-get

Files: *
Copyright: pirate-get contributors
License: AGPL-3.0+
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU Affero General Public
 License version 3 can be found in '/usr/share/common-licenses/AGPL-3'.
EOF

# Copy README as documentation
cp "$PROJECT_ROOT/README.md" "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/"

# Create changelog
cat > "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/changelog.Debian" << EOF
$PACKAGE_NAME ($VERSION) unstable; urgency=low

  * Release version $VERSION
  * Added Textual-based TUI mode
  * Bug fixes and improvements

 -- pirate-get maintainers <pirate-get@example.com>  $(date -R)
EOF
gzip -9 "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/changelog.Debian"

# Create man page
cat > "$PKG_DIR/usr/share/man/man1/pirate-get.1" << EOF
.TH PIRATE-GET 1 "$(date +"%B %Y")" "$VERSION" "User Commands"
.SH NAME
pirate-get \- search and download torrents from The Pirate Bay
.SH SYNOPSIS
.B pirate-get
[\fIOPTIONS\fR] [\fISEARCH TERMS\fR]
.SH DESCRIPTION
pirate-get is a command line tool for searching and downloading torrents
from The Pirate Bay.
.SH OPTIONS
.TP
.B \-\-tui
Launch interactive TUI mode
.TP
.B \-c, \-\-category \fICATEGORY\fR
Filter by category (e.g., Video, Audio, Games)
.TP
.B \-s, \-\-sort \fISORT\fR
Sort results (SeedersDsc, DateDsc, SizeDsc, etc.)
.TP
.B \-t, \-\-transmission
Open magnets with transmission-remote
.TP
.B \-M, \-\-save-magnets
Save magnet links as .magnet files
.TP
.B \-T, \-\-save-torrents
Save .torrent files
.TP
.B \-h, \-\-help
Show help message
.TP
.B \-v, \-\-version
Show version number
.SH EXAMPLES
.TP
Search for a torrent:
pirate-get "ubuntu iso"
.TP
Launch TUI mode:
pirate-get --tui
.TP
Search and send to transmission:
pirate-get -t "linux mint"
.SH FILES
.TP
.I ~/.config/pirate-get
User configuration file
.SH AUTHORS
pirate-get contributors
.SH SEE ALSO
transmission-remote(1)
EOF
gzip -9 "$PKG_DIR/usr/share/man/man1/pirate-get.1"

# Build the package
echo "Building .deb package..."
dpkg-deb --build "$PKG_DIR"

# Move to output location
OUTPUT_DIR="$SCRIPT_DIR/dist"
mkdir -p "$OUTPUT_DIR"
mv "$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" "$OUTPUT_DIR/"

echo -e "${GREEN}Package built successfully!${NC}"
echo "Output: $OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

# Verify package
echo ""
echo "Package info:"
dpkg-deb --info "$OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

# Cleanup
rm -rf "$BUILD_DIR"

echo ""
echo "To install: sudo dpkg -i $OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
echo "To install with dependencies: sudo apt install -f"
