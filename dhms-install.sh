#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# dhms-install.sh — Opinionated Arch Linux Installer with Hyprland
# ─────────────────────────────────────────────────────────────────────────────
# Usage: curl -fsSL https://raw.githubusercontent.com/dhms013/dhmsDots/main/dhms-install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POST_INSTALL_URL="https://raw.githubusercontent.com/dhms013/dhmsDots/main/install.sh"

# Source libraries
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/gum.sh"

# Source steps
source "${SCRIPT_DIR}/steps/00-check.sh"
source "${SCRIPT_DIR}/steps/01-config.sh"
source "${SCRIPT_DIR}/steps/02-partition.sh"
source "${SCRIPT_DIR}/steps/03-base.sh"
source "${SCRIPT_DIR}/steps/04-network.sh"
source "${SCRIPT_DIR}/steps/05-system.sh"
source "${SCRIPT_DIR}/steps/06-users.sh"
source "${SCRIPT_DIR}/steps/07-packages.sh"
source "${SCRIPT_DIR}/steps/08-swap.sh"
source "${SCRIPT_DIR}/steps/09-bootloader.sh"
source "${SCRIPT_DIR}/steps/10-postinstall.sh"
source "${SCRIPT_DIR}/steps/99-cleanup.sh"

show_banner() {
    gum style --border thick --padding "2" \
        "" \
        "  Arch Linux Installer (Hyprland Edition)  " \
        "" \
        "  ⚠️  EXPERIMENTAL - USE AT YOUR OWN RISK ⚠️  " \
        ""
}

show_success() {
    gum style --border thick --padding "2" \
        "" \
        "  ✅ Installation completed successfully!  " \
        "" \
        "  Reboot and enjoy your new Arch Linux system.  " \
        ""
}

ask_reboot() {
    local reboot_now
    reboot_now=$(gum_confirm "Reboot now?" "Reboot" "Stay" true)
    
    if [[ "$reboot_now" == "true" ]]; then
        reboot
    fi
}

main() {
    # Run pre-installation checks
    run_checks
    
    # Show banner
    show_banner
    
    # Configuration
    configure
    show_summary
    
    # Installation steps
    {
        partition
        install_base
        copy_network
        configure_system
        create_users
        install_packages
        setup_swap
        install_limine
        run_post_install
        cleanup
    } | gum_spin "Installing..."
    
    # Show success message
    show_success
    ask_reboot
}

main "$@"
