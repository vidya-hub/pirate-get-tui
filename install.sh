#!/bin/bash
#
# pirate-get Installation Script
# Installs pirate-get with all dependencies including TUI support
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

# Install system dependencies
install_system_deps() {
    local os=$(detect_os)
    
    print_step "Installing system dependencies..."
    
    case $os in
        debian)
            print_step "Detected Debian/Ubuntu"
            sudo apt-get update -qq
            sudo apt-get install -y python3 python3-pip python3-venv libxml2-dev libxslt1-dev
            ;;
        redhat)
            print_step "Detected RHEL/CentOS/Fedora"
            sudo dnf install -y python3 python3-pip python3-devel libxml2-devel libxslt-devel || \
            sudo yum install -y python3 python3-pip python3-devel libxml2-devel libxslt-devel
            ;;
        arch)
            print_step "Detected Arch Linux"
            sudo pacman -Sy --noconfirm python python-pip libxml2 libxslt
            ;;
        macos)
            print_step "Detected macOS"
            if ! command_exists brew; then
                print_warning "Homebrew not found. Installing..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install python3 libxml2 libxslt
            ;;
        *)
            print_warning "Unknown OS. Please ensure Python 3.4+ and pip are installed."
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
    
    if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 4 ]); then
        print_error "Python 3.4+ required. Found: $python_version"
        return 1
    fi
    
    print_success "Python $python_version detected"
    return 0
}

# Install pirate-get
install_pirate_get() {
    local install_type="${1:-user}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    print_step "Installing pirate-get..."
    
    case $install_type in
        user)
            # Install for current user
            pip3 install --user -e "$script_dir"
            print_success "Installed for current user"
            print_warning "Make sure ~/.local/bin is in your PATH"
            ;;
        system)
            # Install system-wide (requires sudo)
            sudo pip3 install -e "$script_dir"
            print_success "Installed system-wide"
            ;;
        venv)
            # Install in virtual environment
            local venv_dir="${2:-$HOME/.venv/pirate-get}"
            print_step "Creating virtual environment at $venv_dir"
            python3 -m venv "$venv_dir"
            source "$venv_dir/bin/activate"
            pip install -e "$script_dir"
            print_success "Installed in virtual environment: $venv_dir"
            print_warning "Activate with: source $venv_dir/bin/activate"
            ;;
        *)
            print_error "Unknown install type: $install_type"
            return 1
            ;;
    esac
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    
    if command_exists pirate-get; then
        print_success "pirate-get command available"
        pirate-get --version
    else
        print_warning "pirate-get not in PATH. Try: pip3 show pirate-get"
    fi
    
    # Test TUI import
    if python3 -c "from pirate.tui import PirateGetApp; print('TUI module OK')" 2>/dev/null; then
        print_success "TUI module working"
    else
        print_warning "TUI module not available. Install textual: pip3 install textual"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --user          Install for current user only (default)"
    echo "  --system        Install system-wide (requires sudo)"
    echo "  --venv [PATH]   Install in virtual environment"
    echo "  --deps-only     Only install system dependencies"
    echo "  --no-deps       Skip system dependencies"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # User install with dependencies"
    echo "  $0 --system             # System-wide install"
    echo "  $0 --venv ~/my-venv     # Install in custom venv"
    echo "  $0 --no-deps --user     # User install, skip system deps"
}

# Main
main() {
    local install_type="user"
    local install_deps=true
    local deps_only=false
    local venv_path=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)
                install_type="user"
                shift
                ;;
            --system)
                install_type="system"
                shift
                ;;
            --venv)
                install_type="venv"
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    venv_path="$2"
                    shift
                fi
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
    if [ "$install_type" = "venv" ] && [ -n "$venv_path" ]; then
        install_pirate_get "$install_type" "$venv_path"
    else
        install_pirate_get "$install_type"
    fi
    
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
}

main "$@"
