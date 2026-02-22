#!/bin/bash
#
# pirate-get Installation Script
# Installs pirate-get with all dependencies including TUI support
#
# Supports modern Python environments (PEP 668) using pipx
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    echo "  🏴‍☠️  pirate-get installer"
    echo "  ========================"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}▸${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        elif [ -f /etc/arch-release ]; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Check if environment is externally managed (PEP 668)
is_externally_managed() {
    local python_path=$(python3 -c "import sys; print(sys.prefix)")
    if [ -f "$python_path/EXTERNALLY-MANAGED" ] || [ -f "/usr/lib/python3."*"/EXTERNALLY-MANAGED" ]; then
        return 0
    fi
    return 1
}

# Install system dependencies
install_system_deps() {
    local os=$(detect_os)
    
    print_step "Installing system dependencies..."
    
    case $os in
        debian)
            print_step "Detected Debian/Ubuntu"
            sudo apt-get update -qq
            sudo apt-get install -y python3 python3-pip python3-venv python3-full pipx libxml2-dev libxslt1-dev
            # Ensure pipx path is available
            pipx ensurepath 2>/dev/null || true
            ;;
        redhat)
            print_step "Detected RHEL/CentOS/Fedora"
            sudo dnf install -y python3 python3-pip python3-devel pipx libxml2-devel libxslt-devel || \
            sudo yum install -y python3 python3-pip python3-devel libxml2-devel libxslt-devel
            ;;
        arch)
            print_step "Detected Arch Linux"
            sudo pacman -Sy --noconfirm python python-pip python-pipx libxml2 libxslt
            ;;
        macos)
            print_step "Detected macOS"
            if ! command_exists brew; then
                print_warning "Homebrew not found. Installing..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install python3 pipx libxml2 libxslt
            pipx ensurepath 2>/dev/null || true
            ;;
        *)
            print_warning "Unknown OS. Please ensure Python 3.8+ and pipx are installed."
            ;;
    esac
}

# Check Python version
check_python() {
    print_step "Checking Python version..."
    
    if ! command_exists python3; then
        print_error "Python 3 is not installed!"
        return 1
    fi
    
    local python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    local major=$(echo $python_version | cut -d. -f1)
    local minor=$(echo $python_version | cut -d. -f2)
    
    if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 8 ]); then
        print_error "Python 3.8+ required. Found: $python_version"
        return 1
    fi
    
    print_success "Python $python_version detected"
    return 0
}

# Install pirate-get using pipx (recommended for modern systems)
install_with_pipx() {
    local source="$1"
    print_step "Installing with pipx (isolated environment)..."
    if ! command_exists pipx; then
        print_step "pipx not found, attempting to install..."
        # Try multiple methods to install pipx
        if command_exists apt-get; then
            sudo apt-get install -y pipx 2>/dev/null && pipx ensurepath 2>/dev/null
        elif command_exists brew; then
            brew install pipx 2>/dev/null && pipx ensurepath 2>/dev/null
        elif command_exists dnf; then
            sudo dnf install -y pipx 2>/dev/null && pipx ensurepath 2>/dev/null
        fi
        
        # Reload PATH to find pipx
        export PATH="$HOME/.local/bin:$PATH"
        hash -r 2>/dev/null || true
    fi
    
    # Final check - if pipx still not available, return failure to trigger fallback
    if ! command_exists pipx; then
        print_warning "Could not install pipx, will use venv instead"
        return 1
    fi
    # Install pirate-get with pipx
    if [ -d "$source" ]; then
        # Local installation
        pipx install "$source" --force
    else
        # From PyPI or git
        pipx install "$source" --force
    fi
    print_success "Installed with pipx"
    print_step "Binary location: $(which pirate-get 2>/dev/null || echo '~/.local/bin/pirate-get')"
}

# Install pirate-get using venv (fallback)
install_with_venv() {
    local source="$1"
    local venv_dir="${2:-$HOME/.local/share/pirate-get/venv}"
    
    print_step "Installing in virtual environment at $venv_dir..."
    
    # Create venv
    mkdir -p "$(dirname "$venv_dir")"
    python3 -m venv "$venv_dir"
    
    # Install in venv
    "$venv_dir/bin/pip" install --upgrade pip
    "$venv_dir/bin/pip" install "$source"
    
    # Create symlinks in ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    ln -sf "$venv_dir/bin/pirate-get" "$HOME/.local/bin/pirate-get"
    ln -sf "$venv_dir/bin/pirate-get-tui" "$HOME/.local/bin/pirate-get-tui" 2>/dev/null || true
    
    print_success "Installed in virtual environment"
    print_warning "Make sure ~/.local/bin is in your PATH"
}

# Install pirate-get (main function)
install_pirate_get() {
    local install_method="${1:-auto}"
    local source="${2:-.}"
    local venv_path="$3"
    
    print_step "Installing pirate-get..."
    
    case $install_method in
        auto)
            # Auto-detect best method
            if is_externally_managed; then
                print_step "Detected externally managed Python (PEP 668)"
                # Try pipx first, fall back to venv if it fails
                if ! install_with_pipx "$source"; then
                    print_step "Falling back to virtual environment..."
                    install_with_venv "$source"
                fi
            elif command_exists pipx; then
                print_step "Using pipx (recommended)"
                install_with_pipx "$source"
            else
                print_step "Using virtual environment"
                install_with_venv "$source"
            fi
            ;;
        pipx)
            install_with_pipx "$source"
            ;;
        venv)
            install_with_venv "$source" "$venv_path"
            ;;
        pip)
            # Force pip install (may break on modern systems)
            print_warning "Using pip directly (may fail on externally managed environments)"
            pip3 install --user "$source" || \
            pip3 install --user --break-system-packages "$source"
            ;;
        system)
            # System-wide install (requires sudo)
            print_warning "Installing system-wide (requires sudo)"
            sudo pip3 install "$source" --break-system-packages 2>/dev/null || \
            sudo pip3 install "$source"
            ;;
        *)
            print_error "Unknown install method: $install_method"
            return 1
            ;;
    esac
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    
    # Reload PATH
    export PATH="$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null || true
    
    if command_exists pirate-get; then
        print_success "pirate-get command available"
        pirate-get --version 2>/dev/null || echo "  (version check skipped)"
    else
        print_warning "pirate-get not found in PATH"
        print_step "Try: export PATH=\"\$HOME/.local/bin:\$PATH\""
        print_step "Then run: pirate-get --help"
    fi
    
    # Test TUI import
    if python3 -c "from pirate.tui import PirateGetApp; print('TUI module OK')" 2>/dev/null; then
        print_success "TUI module working"
    elif pipx runpip pirate-get show textual >/dev/null 2>&1; then
        print_success "TUI dependencies installed"
    else
        print_warning "TUI may need textual. Try: pipx inject pirate-get textual"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --auto          Auto-detect best install method (default)"
    echo "  --pipx          Install with pipx (isolated, recommended)"
    echo "  --venv [PATH]   Install in virtual environment"
    echo "  --pip           Use pip directly (legacy, may fail)"
    echo "  --system        Install system-wide (requires sudo)"
    echo "  --deps-only     Only install system dependencies"
    echo "  --no-deps       Skip system dependencies"
    echo "  --from-git      Install from GitHub repository"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Auto install (pipx or venv)"
    echo "  $0 --pipx               # Force pipx install"
    echo "  $0 --venv ~/my-venv     # Install in custom venv"
    echo "  $0 --from-git           # Install latest from GitHub"
    echo ""
    echo "After installation:"
    echo "  pirate-get 'search'     # CLI search"
    echo "  pirate-get --tui        # Launch TUI"
}

# Main
main() {
    local install_method="auto"
    local install_deps=true
    local deps_only=false
    local venv_path=""
    local source="git+https://github.com/vidya-hub/pirate-get-tui.git"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                install_method="auto"
                shift
                ;;
            --pipx)
                install_method="pipx"
                shift
                ;;
            --venv)
                install_method="venv"
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    venv_path="$2"
                    shift
                fi
                shift
                ;;
            --pip)
                install_method="pip"
                shift
                ;;
            --system)
                install_method="system"
                shift
                ;;
            --deps-only)
                deps_only=true
                shift
                ;;
            --no-deps)
                install_deps=false
                shift
                ;;
            --from-git)
                source="git+https://github.com/vidya-hub/pirate-get-tui.git"
                shift
                ;;
            --from-pypi)
                source="pirate-get"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    print_banner
    
    # Install system dependencies
    if $install_deps; then
        install_system_deps
    fi
    
    if $deps_only; then
        print_success "System dependencies installed"
        exit 0
    fi
    
    # Check Python
    if ! check_python; then
        exit 1
    fi
    
    # Install pirate-get
    install_pirate_get "$install_method" "$source" "$venv_path"
    
    # Verify
    verify_installation
    
    echo ""
    print_success "Installation complete!"
    echo ""
    echo "Quick start:"
    echo "  pirate-get 'search term'     # CLI search"
    echo "  pirate-get --tui             # Launch TUI"
    echo "  pirate-get-tui               # TUI directly"
    echo "  pirate-get -h                # Show help"
    echo ""
    echo "If command not found, run:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
}

main "$@"
