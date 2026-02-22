#!/usr/bin/env bash
#
# Unified Release Build Script for pirate-get
# Builds packages for all supported platforms
#
# Usage: ./build-release.sh [version]
#
# If version is not provided, extracts from pirate/data.py
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Get version from argument or extract from source
get_version() {
    if [[ -n "${1:-}" ]]; then
        echo "$1"
    else
        grep -oP "version = '\K[^']+" "$PROJECT_ROOT/pirate/data.py" 2>/dev/null || \
        grep -o "version = '[^']*'" "$PROJECT_ROOT/pirate/data.py" | cut -d"'" -f2
    fi
}

VERSION=$(get_version "${1:-}")
if [[ -z "$VERSION" ]]; then
    log_error "Could not determine version. Please provide as argument."
    exit 1
fi

log_info "Building pirate-get v$VERSION"
log_info "Project root: $PROJECT_ROOT"

# Create output directory
OUTPUT_DIR="$PROJECT_ROOT/dist/release-$VERSION"
mkdir -p "$OUTPUT_DIR"

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

log_info "Detected OS: $OS, Architecture: $ARCH"

#
# Build Python Package (works on all platforms)
#
build_python_package() {
    log_info "Building Python source distribution and wheel..."
    
    cd "$PROJECT_ROOT"
    
    # Clean previous builds
    rm -rf build/ dist/*.whl dist/*.tar.gz *.egg-info 2>/dev/null || true
    
    # Check for build tools
    if ! python3 -m pip show build &>/dev/null; then
        log_info "Installing build tools..."
        python3 -m pip install --quiet build wheel setuptools
    fi
    
    # Build
    python3 -m build --outdir "$OUTPUT_DIR"
    
    log_success "Python packages built:"
    ls -la "$OUTPUT_DIR"/*.whl "$OUTPUT_DIR"/*.tar.gz 2>/dev/null || true
}

#
# Build Ubuntu .deb package
#
build_ubuntu_package() {
    if [[ "$OS" != "Linux" ]]; then
        log_warn "Skipping Ubuntu build (not on Linux)"
        return 0
    fi
    
    # Check for Debian-based system
    if ! command -v dpkg &>/dev/null; then
        log_warn "Skipping Ubuntu build (dpkg not available)"
        return 0
    fi
    
    log_info "Building Ubuntu .deb package..."
    
    if [[ -x "$SCRIPT_DIR/ubuntu/build-deb.sh" ]]; then
        cd "$SCRIPT_DIR/ubuntu"
        ./build-deb.sh "$VERSION"
        
        # Move built packages to output directory
        mv ./*.deb "$OUTPUT_DIR/" 2>/dev/null || true
        log_success "Ubuntu package built"
    else
        log_warn "Ubuntu build script not found or not executable"
    fi
}

#
# Build macOS package
#
build_macos_package() {
    if [[ "$OS" != "Darwin" ]]; then
        log_warn "Skipping macOS build (not on macOS)"
        return 0
    fi
    
    log_info "Building macOS package..."
    
    if [[ -x "$SCRIPT_DIR/macos/build-macos.sh" ]]; then
        cd "$SCRIPT_DIR/macos"
        ./build-macos.sh "$VERSION"
        
        # Move built packages to output directory
        mv ./*.tar.gz "$OUTPUT_DIR/" 2>/dev/null || true
        log_success "macOS package built"
    else
        log_warn "macOS build script not found or not executable"
    fi
}

#
# Generate checksums
#
generate_checksums() {
    log_info "Generating checksums..."
    
    cd "$OUTPUT_DIR"
    
    if command -v sha256sum &>/dev/null; then
        sha256sum ./* > SHA256SUMS.txt 2>/dev/null || true
    elif command -v shasum &>/dev/null; then
        shasum -a 256 ./* > SHA256SUMS.txt 2>/dev/null || true
    else
        log_warn "No sha256sum tool available, skipping checksums"
        return 0
    fi
    
    log_success "Checksums generated"
}

#
# Main build sequence
#
main() {
    log_info "Starting release build..."
    
    # Always build Python package
    build_python_package
    
    # Platform-specific builds
    build_ubuntu_package
    build_macos_package
    
    # Generate checksums
    generate_checksums
    
    echo ""
    log_success "======================================"
    log_success "Release build complete!"
    log_success "Version: $VERSION"
    log_success "Output directory: $OUTPUT_DIR"
    log_success "======================================"
    echo ""
    log_info "Built files:"
    ls -la "$OUTPUT_DIR"
    echo ""
    log_info "To create a GitHub release, push a tag:"
    log_info "  git tag -a v$VERSION -m 'Release v$VERSION'"
    log_info "  git push origin v$VERSION"
}

main "$@"
