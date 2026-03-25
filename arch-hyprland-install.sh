#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Arch Hyprland Installer Bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/dhms013/dhmsDots/main/arch-hyprland-install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PYTHON_SCRIPT_URL="https://raw.githubusercontent.com/dhms013/dhmsDots/main/arch-hyprland-install.py"

info() { echo -e "\033[0;36m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

check_arch() {
    if ! command -v pacman &>/dev/null; then
        error "This script must be run from Arch Linux live environment"
        exit 1
    fi
}

install_python() {
    if command -v python &>/dev/null; then
        info "Python already installed: $(python --version)"
        return 0
    fi

    info "Installing Python..."
    pacman -Sy --noconfirm python || {
        error "Failed to install Python via pacman"
        exit 1
    }
    success "Python installed: $(python --version)"
}

install_archinstall() {
    if python -c "import archinstall" 2>/dev/null; then
        info "archinstall already available"
        return 0
    fi

    info "Installing archinstall..."
    if pacman -Sy --noconfirm archinstall 2>/dev/null; then
        success "archinstall installed via pacman"
    else
        warn "Installing archinstall via pip..."
        pip install --break-system-packages archinstall || {
            error "Failed to install archinstall"
            exit 1
        }
        success "archinstall installed via pip"
    fi
}

main() {
    check_root
    check_arch

    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  Arch Linux Installer (Hyprland Edition)            ║"
    echo "║  Bootstrap Mode                                     ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""

    install_python
    install_archinstall

    info "Downloading Python installer..."
    INSTALLER_SCRIPT="/tmp/arch-hyprland-install.py"
    
    if ! curl -fsSL "$PYTHON_SCRIPT_URL" -o "$INSTALLER_SCRIPT"; then
        error "Failed to download installer"
        exit 1
    fi
    chmod +x "$INSTALLER_SCRIPT"

    info "Starting Python installer..."
    echo ""

    python "$INSTALLER_SCRIPT"
}

main "$@"
