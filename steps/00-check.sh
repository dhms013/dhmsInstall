#!/bin/bash
# Step 00: Pre-installation checks

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

install_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi

    info "Installing gum..."
    pacman -Sy --noconfirm gum
    success "gum installed"
}

run_checks() {
    check_root
    check_arch
    install_gum
}
