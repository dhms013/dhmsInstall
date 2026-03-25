#!/bin/bash
# Step 07: Package installation

install_packages() {
    info "Installing packages..."
    
    cat >> /mnt/etc/pacman.conf <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    
    arch-chroot /mnt bash -euo pipefail <<'CHROOT'
set -e

pacman -Sy --noconfirm

pacman -S --noconfirm \
    pipewire pipewire-alsa pipewire-jack pipewire-pulse \
    wireplumber gst-plugin-pipewire libpulse \
    bluez bluez-utils \
    hyprland dunst kitty uwsm wofi dolphin \
    xdg-desktop-portal-hyprland \
    qt5-wayland qt6-wayland \
    polkit-kde-agent grim slurp \
    sddm sddm-kcm \
    zsh zsh-completions \
    btop fastfetch \
    zram-generator

systemctl enable bluetooth
systemctl enable sddm

CHROOT
    
    success "Packages installed"
}
