#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# dhms-install.sh — Opinionated Arch Linux Installer with Hyprland
# ─────────────────────────────────────────────────────────────────────────────
# Usage: curl -fsSL https://raw.githubusercontent.com/dhms013/dhmsDots/main/dhms-install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

POST_INSTALL_URL="https://raw.githubusercontent.com/dhms013/dhmsDots/main/install.sh"

GUM_INSTALLED=false

install_gum() {
    if command -v gum &>/dev/null; then
        GUM_INSTALLED=true
        return 0
    fi

    echo "[INFO] Installing gum..."
    
    local gum_ver="0.14.5"
    local gum_url="https://github.com/charmbracelet/gum/releases/download/v${gum_ver}/gum_${gum_ver}_linux_amd64.tar.gz"
    
    cd /tmp
    curl -fsSL "$gum_url" -o gum.tar.gz
    tar -xzf gum.tar.gz
    mv gum /usr/local/bin/gum
    chmod +x /usr/local/bin/gum
    rm -f gum.tar.gz LICENSE README.md
    
    cd - >/dev/null
    GUM_INSTALLED=true
    echo "[OK] gum installed"
}

info() { 
    if command -v gum &>/dev/null; then
        gum log --level info "$1"
    else
        echo "[INFO] $1"
    fi
}
warn() { 
    if command -v gum &>/dev/null; then
        gum log --level warn "$1"
    else
        echo "[WARN] $1"
    fi
}
error() { 
    if command -v gum &>/dev/null; then
        gum log --level error "$1"
    else
        echo "[ERROR] $1"
    fi
}
success() { 
    if command -v gum &>/dev/null; then
        gum log --level info "✓ $1"
    else
        echo "[OK] $1"
    fi
}

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

detect_gpu() {
    if lspci | grep -qi nvidia; then
        GPU_DRIVER="nvidia"
    elif lspci | grep -qi amd; then
        GPU_DRIVER="amdgpu"
    elif lspci | grep -qi intel; then
        GPU_DRIVER="intel"
    else
        GPU_DRIVER="auto"
    fi
}

configure_installation() {
    HOSTNAME=$(gum input --placeholder "archlinux" --value "archlinux" --header "Hostname")
    : "${HOSTNAME:=archlinux}"
    
    USERNAME=$(gum input --placeholder "arch" --value "arch" --header "Username")
    : "${USERNAME:=arch}"
    
    USER_PASSWORD=$(gum input --password --placeholder "User password" --header "Password")
    while [[ -z "$USER_PASSWORD" ]]; do
        warn "Password cannot be empty"
        USER_PASSWORD=$(gum input --password --placeholder "User password" --header "Password")
    done
    
    ROOT_PASSWORD=$(gum input --password --placeholder "Root password (Enter for same)" --header "Root Password")
    : "${ROOT_PASSWORD:=$USER_PASSWORD}"
    
    LOCALE=$(gum input --placeholder "en_US.UTF-8" --value "en_US.UTF-8" --header "Locale")
    : "${LOCALE:=en_US.UTF-8}"
    
    TIMEZONE=$(gum input --placeholder "America/New_York" --value "America/New_York" --header "Timezone")
    : "${TIMEZONE:=America/New_York}"
    
    KEYBOARD=$(gum input --placeholder "us" --value "us" --header "Keyboard Layout")
    : "${KEYBOARD:=us}"
    
    mirror_regions=(
        "United_States" "Canada" "Mexico" "Brazil" "Colombia"
        "Argentina" "Chile" "Peru" "United_Kingdom" "Germany"
        "France" "Netherlands" "Spain" "Sweden" "Russia"
        "Poland" "Japan" "China" "Taiwan" "Singapore"
        "Australia" "New_Zealand" "India" "Indonesia" "Thailand"
    )
    
    MIRROR_REGION=$(gum choose --header "Mirror Region" --cursor "● " --selected "○ " "${mirror_regions[@]}")
    : "${MIRROR_REGION:=United_States}"
    
    echo ""
    gum style --border normal --padding "1" "Available Drives:"
    lsblk -d -n -o NAME,SIZE,TYPE,MODEL | awk '{print NR". /dev/"$1" ("$2", "$3")"}'
    
    DRIVE_NUM=$(gum input --placeholder "Enter number" --header "Select Drive Number")
    : "${DRIVE_NUM:=1}"
    
    DRIVE="/dev/$(lsblk -d -n -o NAME | sed -n "${DRIVE_NUM}p")"
    
    if [[ ! -b "$DRIVE" ]]; then
        error "Invalid drive selection"
        exit 1
    fi
    
    WIPE_DRIVE=$(gum confirm --default=false --prompt.accept "Yes, wipe drive" --prompt.reject "No, keep data" "Wipe drive completely?")
}

show_summary() {
    echo ""
    gum style --border double --padding "1 2" --title "Installation Summary" \
        "Hostname:     $HOSTNAME" \
        "Username:     $USERNAME" \
        "Drive:        $DRIVE" \
        "Wipe:         $([ "$WIPE_DRIVE" = true ] && echo "Yes" || echo "No")" \
        "Locale:       $LOCALE" \
        "Timezone:     $TIMEZONE" \
        "Keyboard:     $KEYBOARD" \
        "Mirror:       $MIRROR_REGION" \
        "GPU Driver:  $GPU_DRIVER" \
        "Kernel:       linux-zen"
    
    local confirm
    confirm=$(gum confirm --default=false --prompt.accept "Proceed" --prompt.reject "Cancel" "Proceed with installation?")
    
    if [[ "$confirm" != "true" ]]; then
        info "Installation cancelled"
        exit 0
    fi
}

partition_drive() {
    info "Partitioning $DRIVE..."
    
    if [[ "$WIPE_DRIVE" == "true" ]]; then
        wipefs -af "$DRIVE" 2>/dev/null || true
        dd if=/dev/zero of="$DRIVE" bs=512 count=1 2>/dev/null || true
    fi
    
    parted -s "$DRIVE" mklabel gpt
    parted -s "$DRIVE" mkpart primary fat32 1MiB 513MiB
    parted -s "$DRIVE" set 1 boot on
    parted -s "$DRIVE" set 1 esp on
    parted -s "$DRIVE" mkpart primary ext4 513MiB 100%
    
    PART_BOOT="${DRIVE}1"
    PART_ROOT="${DRIVE}2"
    
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$PART_ROOT")
    
    mkfs.fat -F 32 "$PART_BOOT"
    mkfs.ext4 -F "$PART_ROOT"
    
    mount "$PART_ROOT" /mnt
    mkdir -p /mnt/boot
    mount "$PART_BOOT" /mnt/boot
    
    success "Partitions created"
}

install_base() {
    info "Installing base system..."
    
    local base_packages=(
        "base" "linux-zen" "linux-firmware"
        "sudo" "vim" "git" "curl"
        "efibootmgr" "limine"
    )
    
    local gpu_packages=()
    case $GPU_DRIVER in
        nvidia)
            gpu_packages=(nvidia nvidia-utils nvidia-settings)
            ;;
        nvidia-open)
            gpu_packages=(nvidia-open-dkms nvidia-utils)
            ;;
        amdgpu)
            gpu_packages=(mesa xf86-video-amdgpu vulkan-radeon)
            ;;
        intel)
            gpu_packages=(mesa xf86-video-intel intel-media-driver vulkan-intel)
            ;;
    esac
    
    pacstrap -K /mnt "${base_packages[@]}"
    
    if [[ ${#gpu_packages[@]} -gt 0 ]]; then
        pacstrap -K /mnt "${gpu_packages[@]}"
    fi
    
    genfstab -U /mnt > /mnt/etc/fstab
    
    success "Base system installed"
}

copy_iso_network() {
    info "Copying network configuration..."
    
    if [[ -d /var/lib/iwd ]]; then
        mkdir -p /mnt/var/lib/iwd
        cp /var/lib/iwd/*.psk /mnt/var/lib/iwd/ 2>/dev/null || true
    fi
    
    if [[ -f /etc/systemd/network ]]; then
        mkdir -p /mnt/etc/systemd/network
        cp /etc/systemd/network/* /mnt/etc/systemd/network/ 2>/dev/null || true
    fi
    
    arch-chroot /mnt systemctl enable systemd-networkd 2>/dev/null || true
    arch-chroot /mnt systemctl enable systemd-resolved 2>/dev/null || true
    
    success "Network configuration copied"
}

configure_system() {
    info "Configuring system..."
    
    arch-chroot /mnt bash -euo pipefail <<'CHROOT'
set -e

ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
hwclock --systohc

sed -i "/^#${LOCALE}/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "KEYMAP=${KEYBOARD}" > /etc/vconsole.conf

echo "${HOSTNAME}" > /etc/hostname
cat >> /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color$/Color/' /etc/pacman.conf
echo "ILoveCandy" >> /etc/pacman.conf

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

CHROOT
    
    success "System configured"
}

create_users() {
    info "Creating users..."
    
    arch-chroot /mnt useradd -m -G wheel,input,audio,video,lp -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd -R /mnt
    echo "root:$ROOT_PASSWORD" | chpasswd -R /mnt
    
    success "Users created"
}

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

setup_swap() {
    info "Setting up swap..."
    
    arch-chroot /mnt bash -euo pipefail <<'CHROOT'
set -e

cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
compression-algorithm = zstd
EOF

systemctl enable systemd-zram-setup@zram0.service

CHROOT
    
    success "Swap configured"
}

install_limine() {
    info "Installing Limine bootloader..."
    
    arch-chroot /mnt bash -euo pipefail <<CHROOT
set -e

limine-install -i

mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
cp /usr/share/limine/BOOTIA32.EFI /boot/EFI/BOOT/ 2>/dev/null || true

cat > /boot/limine.cfg <<'LIMINE_EOF'
timeout: 5
default_entry: 0

:Arch Linux
    protocol: linux
    kernel_path: boot:///vmlinuz-linux-zen
    initrd_path: boot:///initramfs-linux-zen.img
    cmdline: root=PARTUUID=${ROOT_PARTUUID} rw
LIMINE_EOF

cat > /boot/EFI/BOOT/limine.cfg <<'LIMINE_EOF'
timeout: 5
default_entry: 0

:Arch Linux
    protocol: linux
    kernel_path: boot:///vmlinuz-linux-zen
    initrd_path: boot:///initramfs-linux-zen.img
    cmdline: root=PARTUUID=${ROOT_PARTUUID} rw
LIMINE_EOF

CHROOT
    
    success "Limine installed"
}

run_post_install() {
    info "Running post-installation..."
    
    arch-chroot /mnt bash -euo pipefail <<CHROOT
set -e

curl -fsSL ${POST_INSTALL_URL} | bash

CHROOT
    
    success "Post-installation completed"
}

cleanup() {
    info "Cleaning up..."
    umount -R /mnt 2>/dev/null || true
    success "Cleanup completed"
}

main() {
    check_root
    check_arch
    install_gum
    
    gum style --border thick --padding "2" --title "dhms-install" \
        "" \
        "  Arch Linux Installer (Hyprland Edition)  " \
        "" \
        "  ⚠️  EXPERIMENTAL - USE AT YOUR OWN RISK ⚠️  " \
        ""
    
    configure_installation
    show_summary
    
    {
        partition_drive
        install_base
        copy_iso_network
        configure_system
        create_users
        install_packages
        setup_swap
        install_limine
        run_post_install
        cleanup
    } | gum spin --spinner line --title "Installing..." --show-output
    
    gum style --border thick --padding "2" --title "Success!" \
        "" \
        "  ✅ Installation completed successfully!  " \
        "" \
        "  Reboot and enjoy your new Arch Linux system.  " \
        ""
    
    local reboot_now
    reboot_now=$(gum confirm --default=true --prompt.accept "Reboot" --prompt.reject "Stay" "Reboot now?")
    
    if [[ "$reboot_now" == "true" ]]; then
        reboot
    fi
}

main "$@"
