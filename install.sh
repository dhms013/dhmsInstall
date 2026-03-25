#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — Opinionated Arch Linux Installer with Hyprland
# ─────────────────────────────────────────────────────────────────────────────
# Usage: curl -fsSL https://raw.githubusercontent.com/dhms013/dhmsInstall/main/install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

POST_INSTALL_URL="https://raw.githubusercontent.com/dhms013/dhmsInstall/main/install.sh"

install_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi
    echo "[INFO] Installing gum..."
    pacman -Sy --noconfirm gum
    echo "[OK] gum installed"
}

info() { gum log --level info "$1" 2>/dev/null || echo "[INFO] $1"; }
warn() { gum log --level warn "$1" 2>/dev/null || echo "[WARN] $1"; }
error() { gum log --level error "$1" 2>/dev/null || echo "[ERROR] $1"; }
success() { gum log --level info "✓ $1" 2>/dev/null || echo "[OK] $1"; }

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

print_banner() {
    gum style --border thick --padding "2" \
        "" \
        "  Arch Linux Installer (Hyprland Edition)  " \
        "" \
        "  ⚠️  EXPERIMENTAL - USE AT YOUR OWN RISK ⚠️  " \
        ""
}

print_section() {
    local title="$1"
    gum style --border normal --padding "1" "$title"
}

print_config() {
    local key="$1"
    local value="$2"
    gum style --faint "  $key:" && echo " $value"
}

configure() {
    echo ""
    print_section "Hostname"
    HOSTNAME=$(gum input --placeholder "archlinux" --header "Enter hostname")
    : "${HOSTNAME:=archlinux}"
    print_config "Hostname" "$HOSTNAME"
    
    echo ""
    print_section "Username"
    USERNAME=$(gum input --placeholder "arch" --header "Enter username")
    : "${USERNAME:=arch}"
    print_config "Username" "$USERNAME"
    
    echo ""
    print_section "Password"
    USER_PASSWORD=$(gum input --password --placeholder "User password" --header "Enter password")
    while [[ -z "$USER_PASSWORD" ]]; do
        warn "Password cannot be empty"
        USER_PASSWORD=$(gum input --password --placeholder "User password" --header "Enter password")
    done
    print_config "Password" "********"
    
    ROOT_PASSWORD=$(gum input --password --placeholder "Root password (Enter for same)" --header "Enter root password")
    : "${ROOT_PASSWORD:=$USER_PASSWORD}"
    print_config "Root password" "********"
    
    echo ""
    print_section "Language"
    echo "Select your preferred language:"
    
    locales=(
        "en_US.UTF-8 (English, US)"
        "en_GB.UTF-8 (English, UK)"
        "en_AU.UTF-8 (English, Australia)"
        "de_DE.UTF-8 (German, Germany)"
        "de_AT.UTF-8 (German, Austria)"
        "de_CH.UTF-8 (German, Switzerland)"
        "fr_FR.UTF-8 (French, France)"
        "fr_CA.UTF-8 (French, Canada)"
        "es_ES.UTF-8 (Spanish, Spain)"
        "es_MX.UTF-8 (Spanish, Mexico)"
        "pt_BR.UTF-8 (Portuguese, Brazil)"
        "pt_PT.UTF-8 (Portuguese, Portugal)"
        "it_IT.UTF-8 (Italian, Italy)"
        "ru_RU.UTF-8 (Russian, Russia)"
        "ja_JP.UTF-8 (Japanese, Japan)"
        "zh_CN.UTF-8 (Chinese, Simplified)"
        "zh_TW.UTF-8 (Chinese, Traditional)"
        "ko_KR.UTF-8 (Korean, South Korea)"
        "id_ID.UTF-8 (Indonesian, Indonesia)"
        "th_TH.UTF-8 (Thai, Thailand)"
        "tr_TR.UTF-8 (Turkish, Turkey)"
        "pl_PL.UTF-8 (Polish, Poland)"
        "nl_NL.UTF-8 (Dutch, Netherlands)"
    )
    
    IFS=$'\n' sorted_locales=($(sort <<<"${locales[*]}")); unset IFS
    LOCALE_CHOICE=$(printf '%s\n' "${sorted_locales[@]}" | gum choose --header "Language" --cursor "> ")
    LOCALE="${LOCALE_CHOICE%% (*}"
    print_config "Language" "$LOCALE"
    
    echo ""
    print_section "Timezone"
    echo "Select your timezone:"
    
    timezones=(
        "America/New_York (US Eastern)"
        "America/Chicago (US Central)"
        "America/Denver (US Mountain)"
        "America/Los_Angeles (US Pacific)"
        "America/Toronto (Canada Eastern)"
        "America/Vancouver (Canada Pacific)"
        "America/Mexico_City (Mexico)"
        "America/Sao_Paulo (Brazil)"
        "Europe/London (UK)"
        "Europe/Paris (France)"
        "Europe/Berlin (Germany)"
        "Europe/Madrid (Spain)"
        "Europe/Rome (Italy)"
        "Europe/Moscow (Russia)"
        "Europe/Istanbul (Turkey)"
        "Asia/Tokyo (Japan)"
        "Asia/Shanghai (China)"
        "Asia/Hong_Kong (Hong Kong)"
        "Asia/Taipei (Taiwan)"
        "Asia/Seoul (South Korea)"
        "Asia/Singapore (Singapore)"
        "Asia/Jakarta (Indonesia)"
        "Asia/Bangkok (Thailand)"
        "Australia/Sydney (Australia Eastern)"
        "Australia/Perth (Australia Western)"
        "Pacific/Auckland (New Zealand)"
    )
    
    IFS=$'\n' sorted_timezones=($(sort <<<"${timezones[*]}")); unset IFS
    TIMEZONE_CHOICE=$(printf '%s\n' "${sorted_timezones[@]}" | gum choose --header "Timezone" --cursor "> ")
    TIMEZONE="${TIMEZONE_CHOICE%% (*}"
    print_config "Timezone" "$TIMEZONE"
    
    echo ""
    print_section "Keyboard Layout"
    echo "Select your keyboard layout:"
    
    keyboards=(
        "us (US English)"
        "uk (UK English)"
        "de (German)"
        "fr (French)"
        "es (Spanish)"
        "pt (Portuguese)"
        "it (Italian)"
        "ru (Russian)"
        "jp (Japanese)"
        "br (Brazilian)"
        "dvorak (Dvorak)"
    )
    
    IFS=$'\n' sorted_keyboards=($(sort <<<"${keyboards[*]}")); unset IFS
    KEYBOARD_CHOICE=$(printf '%s\n' "${sorted_keyboards[@]}" | gum choose --header "Keyboard" --cursor "> ")
    KEYBOARD="${KEYBOARD_CHOICE%% (*}"
    print_config "Keyboard" "$KEYBOARD"
    
    echo ""
    print_section "Mirror Region"
    echo "Select the mirror region (closest to you):"
    
    mirror_regions=(
        "Argentina" "Australia" "Austria" "Bangladesh" "Belarus"
        "Belgium" "Bolivia" "Brazil" "Bulgaria" "Canada"
        "Chile" "China" "Colombia" "Costa Rica" "Croatia"
        "Czech Republic" "Denmark" "Ecuador" "Finland" "France"
        "Germany" "Greece" "Hungary" "Iceland" "India"
        "Indonesia" "Iran" "Ireland" "Israel" "Italy"
        "Japan" "Kazakhstan" "Kenya" "Latvia" "Lithuania"
        "Luxembourg" "Macedonia" "Malaysia" "Mexico" "Netherlands"
        "New Zealand" "Nicaragua" "Norway" "Pakistan" "Paraguay"
        "Peru" "Philippines" "Poland" "Portugal" "Romania"
        "Russia" "Serbia" "Singapore" "Slovakia" "Slovenia"
        "South Africa" "South Korea" "Spain" "Sweden" "Switzerland"
        "Taiwan" "Thailand" "Turkey" "Ukraine" "United Kingdom"
        "United States" "Uruguay" "Vietnam"
    )
    
    IFS=$'\n' sorted_mirrors=($(sort <<<"${mirror_regions[*]}")); unset IFS
    MIRROR_REGION=$(printf '%s\n' "${sorted_mirrors[@]}" | gum choose --header "Mirror" --cursor "> ")
    print_config "Mirror" "$MIRROR_REGION"
    
    echo ""
    print_section "GPU Driver"
    echo "Select your GPU driver:"
    
    gpu_options=(
        "Auto-detect (Recommended)"
        "AMD/ATI (Open Source)"
        "Intel (Open Source)"
        "NVIDIA (Open Kernel)"
        "NVIDIA (Proprietary)"
    )
    
    GPU_CHOICE=$(printf '%s\n' "${gpu_options[@]}" | gum choose --header "GPU" --cursor "> ")
    
    case "$GPU_CHOICE" in
        "NVIDIA (Proprietary)") GPU_DRIVER="nvidia" ;;
        "NVIDIA (Open Kernel)") GPU_DRIVER="nvidia-open" ;;
        "AMD/ATI (Open Source)") GPU_DRIVER="amdgpu" ;;
        "Intel (Open Source)") GPU_DRIVER="intel" ;;
        *) detect_gpu ;;
    esac
    print_config "GPU Driver" "$GPU_DRIVER"
    
    echo ""
    print_section "Drive Selection"
    echo "Available drives:"
    lsblk -d -n -o NAME,SIZE,TYPE,MODEL | awk '{print "  " $1 ": " $2 " (" $3 ")"}'
    
    local drive_count
    drive_count=$(lsblk -d -n -o NAME | wc -l)
    
    DRIVE_NUM=$(gum input --placeholder "1" --header "Drive number (1-$drive_count)")
    : "${DRIVE_NUM:=1}"
    
    if [[ "$DRIVE_NUM" -lt 1 ]] || [[ "$DRIVE_NUM" -gt "$drive_count" ]]; then
        DRIVE_NUM=1
    fi
    
    DRIVE="/dev/$(lsblk -d -n -o NAME | sed -n "${DRIVE_NUM}p")"
    
    if [[ ! -b "$DRIVE" ]]; then
        error "Invalid drive selection"
        exit 1
    fi
    print_config "Drive" "$DRIVE"
    
    echo ""
    gum style --border double --padding "1" --foreground 196 "⚠️  WARNING: This will wipe the drive!"
    WIPE_CHOICE=$(gum confirm --default=false --affirmative "Yes, wipe drive" --negative "No, keep data" "Wipe drive completely?")
    WIPE_DRIVE="$WIPE_CHOICE"
    print_config "Wipe" "$( [ "$WIPE_DRIVE" = "true" ] && echo "Yes" || echo "No" )"
}

show_summary() {
    clear
    gum style --border thick --padding "2" \
        "" \
        "  Installation Summary  " \
        "" \
        "  Please review your configuration  " \
        ""
    
    echo ""
    gum style --border double --padding "1 2" \
        "" \
        "  Hostname:     $HOSTNAME" \
        "  Username:     $USERNAME" \
        "  Drive:        $DRIVE" \
        "  Wipe:         $([ "$WIPE_DRIVE" = "true" ] && echo "Yes" || echo "No")" \
        "  Locale:       $LOCALE" \
        "  Timezone:     $TIMEZONE" \
        "  Keyboard:     $KEYBOARD" \
        "  Mirror:       $MIRROR_REGION" \
        "  GPU Driver:   $GPU_DRIVER" \
        "  Kernel:       linux-zen" \
        ""
    
    local confirm
    confirm=$(gum confirm --default=false --affirmative "Proceed" --negative "Cancel" "Proceed with installation?")
    
    if [[ "$confirm" != "true" ]]; then
        info "Installation cancelled"
        exit 0
    fi
}

partition() {
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

copy_network() {
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
    
    print_banner
    configure
    show_summary
    
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
    } | gum spin --spinner line -- "Installing..." --show-output
    
    gum style --border thick --padding "2" \
        "" \
        "  ✅ Installation completed successfully!  " \
        "" \
        "  Reboot and enjoy your new Arch Linux system.  " \
        ""
    
    local reboot_now
    reboot_now=$(gum confirm --default=true --affirmative "Reboot" --negative "Stay" "Reboot now?")
    
    if [[ "$reboot_now" == "true" ]]; then
        reboot
    fi
}

main "$@"
