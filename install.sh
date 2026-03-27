#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — dhmsInstall: Arch Linux Installer (Hyprland Edition)
# ─────────────────────────────────────────────────────────────────────────────
# Usage: curl -fsSL https://raw.githubusercontent.com/dhms013/dhmsInstall/main/install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Globals ──────────────────────────────────────────────────────────────────
HOSTNAME=""
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
LOCALE="en_US.UTF-8"
TIMEZONE="Asia/Jakarta"
KEYBOARD="us"
MIRROR_REGION="Indonesia"
GPU_DRIVER="auto"
DRIVE=""
PART_BOOT=""
PART_ROOT=""
ROOT_PARTUUID=""

# ─── Logging helpers ──────────────────────────────────────────────────────────
info() { gum log --level info "$1" 2>/dev/null || echo "[INFO]  $1"; }
warn() { gum log --level warn "$1" 2>/dev/null || echo "[WARN]  $1"; }
error() { gum log --level error "$1" 2>/dev/null || echo "[ERROR] $1"; }
success() { gum log --level info "✓ $1" 2>/dev/null || echo "[OK]    $1"; }

# ─── Sanity checks ────────────────────────────────────────────────────────────
check_root() {
  [[ $EUID -eq 0 ]] || {
    echo "[ERROR] Run as root"
    exit 1
  }
}

check_arch() {
  command -v pacman &>/dev/null || {
    echo "[ERROR] Not an Arch environment"
    exit 1
  }
}

install_gum() {
  command -v gum &>/dev/null && return 0
  echo "[INFO] Installing gum..."
  pacman -Sy --noconfirm gum
  success "gum installed"
}

# ─── GPU auto-detect ──────────────────────────────────────────────────────────
detect_gpu() {
  if lspci 2>/dev/null | grep -qi nvidia; then
    GPU_DRIVER="nvidia"
  elif lspci 2>/dev/null | grep -qi " amd\| ati\|radeon"; then
    GPU_DRIVER="amdgpu"
  elif lspci 2>/dev/null | grep -qi intel; then
    GPU_DRIVER="intel"
  else
    GPU_DRIVER="mesa"
  fi
}

# ─── Banner ───────────────────────────────────────────────────────────────────
print_banner() {
  clear
  gum style \
    --border double \
    --border-foreground 99 \
    --padding "1 4" \
    --margin "1 2" \
    --bold \
    "  dhmsInstall — Arch Linux (Hyprland Edition)  " \
    "" \
    "  ⚠  EXPERIMENTAL — USE AT YOUR OWN RISK  ⚠  "
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Configuration prompts
# ─────────────────────────────────────────────────────────────────────────────

ask_hostname() {
  HOSTNAME=$(gum input \
    --placeholder "archlinux" \
    --header "  Hostname" \
    --header.foreground 99 \
    --prompt "> " \
    --value "${HOSTNAME:-}")
  : "${HOSTNAME:=archlinux}"
}

ask_username() {
  USERNAME=$(gum input \
    --placeholder "arch" \
    --header "  Username" \
    --header.foreground 99 \
    --prompt "> " \
    --value "${USERNAME:-}")
  : "${USERNAME:=arch}"
}

ask_password() {
  while true; do
    USER_PASSWORD=$(gum input \
      --password \
      --placeholder "Enter user password" \
      --header "  User Password" \
      --header.foreground 99 \
      --prompt "> ")
    [[ -n "$USER_PASSWORD" ]] && break
    warn "Password cannot be empty"
  done

  local confirm
  confirm=$(gum input \
    --password \
    --placeholder "Confirm user password" \
    --header "  Confirm User Password" \
    --header.foreground 99 \
    --prompt "> ")
  if [[ "$USER_PASSWORD" != "$confirm" ]]; then
    warn "Passwords do not match, try again"
    ask_password
    return
  fi

  ROOT_PASSWORD=$(gum input \
    --password \
    --placeholder "Leave empty to use same as user" \
    --header "  Root Password (optional)" \
    --header.foreground 99 \
    --prompt "> ")
  : "${ROOT_PASSWORD:=$USER_PASSWORD}"
}

ask_locale() {
  local all_locales=(
    "en_US.UTF-8"
    "en_GB.UTF-8"
    "en_AU.UTF-8"
    "id_ID.UTF-8"
    "de_DE.UTF-8"
    "fr_FR.UTF-8"
    "es_ES.UTF-8"
    "pt_BR.UTF-8"
    "pt_PT.UTF-8"
    "it_IT.UTF-8"
    "ru_RU.UTF-8"
    "ja_JP.UTF-8"
    "zh_CN.UTF-8"
    "zh_TW.UTF-8"
    "ko_KR.UTF-8"
    "th_TH.UTF-8"
    "tr_TR.UTF-8"
    "pl_PL.UTF-8"
    "nl_NL.UTF-8"
  )
  LOCALE=$(printf '%s\n' "${all_locales[@]}" |
    gum choose \
      --header "  Select Locale" \
      --header.foreground 99 \
      --cursor "> " \
      --selected "${LOCALE:-en_US.UTF-8}")
  : "${LOCALE:=en_US.UTF-8}"
}

ask_timezone() {
  # Two-step: region → city (reads from real zoneinfo)
  local regions=(
    "Africa" "America" "Antarctica" "Arctic"
    "Asia" "Atlantic" "Australia" "Europe"
    "Indian" "Pacific" "UTC"
  )
  local region
  region=$(printf '%s\n' "${regions[@]}" |
    gum choose \
      --header "  Select Timezone Region" \
      --header.foreground 99 \
      --cursor "> " \
      --selected "Asia")
  : "${region:=Asia}"

  if [[ "$region" == "UTC" ]]; then
    TIMEZONE="UTC"
    return
  fi

  local cities=()
  while IFS= read -r city; do
    cities+=("$city")
  done < <(find "/usr/share/zoneinfo/$region" -maxdepth 1 -type f 2>/dev/null |
    sed "s|/usr/share/zoneinfo/$region/||" | sort)

  if [[ ${#cities[@]} -eq 0 ]]; then
    TIMEZONE="UTC"
    return
  fi

  local city
  city=$(printf '%s\n' "${cities[@]}" |
    gum choose \
      --header "  Select City — $region" \
      --header.foreground 99 \
      --cursor "> ")
  : "${city:=Jakarta}"
  TIMEZONE="${region}/${city}"
}

ask_keyboard() {
  local keyboards=(
    "us" "uk" "de" "fr" "es" "pt" "it"
    "ru" "br" "dvorak" "colemak" "jp106"
    "la-latin1" "nl" "pl" "ro" "sv-latin1" "tr"
  )
  KEYBOARD=$(printf '%s\n' "${keyboards[@]}" |
    gum choose \
      --header "  Select Keyboard Layout" \
      --header.foreground 99 \
      --cursor "> " \
      --selected "${KEYBOARD:-us}")
  : "${KEYBOARD:=us}"
}

ask_mirror() {
  local regions=(
    "Argentina" "Australia" "Austria" "Bangladesh" "Belarus" "Belgium"
    "Bolivia" "Brazil" "Bulgaria" "Canada" "Chile" "China" "Colombia"
    "Croatia" "Czech Republic" "Denmark" "Ecuador" "Finland" "France"
    "Germany" "Greece" "Hungary" "Iceland" "India" "Indonesia" "Iran"
    "Ireland" "Israel" "Italy" "Japan" "Kazakhstan" "Kenya" "Latvia"
    "Lithuania" "Luxembourg" "Malaysia" "Mexico" "Netherlands"
    "New Zealand" "Norway" "Pakistan" "Paraguay" "Peru" "Philippines"
    "Poland" "Portugal" "Romania" "Russia" "Serbia" "Singapore"
    "Slovakia" "Slovenia" "South Africa" "South Korea" "Spain" "Sweden"
    "Switzerland" "Taiwan" "Thailand" "Turkey" "Ukraine" "United Kingdom"
    "United States" "Uruguay" "Vietnam"
  )
  MIRROR_REGION=$(printf '%s\n' "${regions[@]}" |
    gum choose \
      --header "  Select Mirror Region (closest to you)" \
      --header.foreground 99 \
      --cursor "> " \
      --selected "${MIRROR_REGION:-Indonesia}")
  : "${MIRROR_REGION:=Indonesia}"
}

ask_gpu() {
  local gpu_options=(
    "Auto-detect (Recommended)"
    "AMD / ATI  —  amdgpu (open source)"
    "Intel      —  intel  (open source)"
    "NVIDIA     —  nvidia-open (open kernel)"
    "NVIDIA     —  nvidia  (proprietary)"
  )
  local choice
  choice=$(printf '%s\n' "${gpu_options[@]}" |
    gum choose \
      --header "  Select GPU Driver" \
      --header.foreground 99 \
      --cursor "> ")
  : "${choice:=Auto-detect (Recommended)}"

  case "$choice" in
  *"nvidia  (proprietary)"*) GPU_DRIVER="nvidia" ;;
  *"nvidia-open"*) GPU_DRIVER="nvidia-open" ;;
  *"amdgpu"*) GPU_DRIVER="amdgpu" ;;
  *"intel"*) GPU_DRIVER="intel" ;;
  *) detect_gpu ;;
  esac
}

ask_drive() {
  local drives=()
  local labels=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local name size type model
    read -r name size type model <<<"$line"
    [[ "$type" == "rom" ]] && continue
    [[ "$type" == "loop" ]] && continue
    [[ "$name" =~ ^loop ]] && continue
    [[ "$name" =~ ^sr ]] && continue
    [[ "$name" =~ ^dm- ]] && continue
    drives+=("/dev/$name")
    labels+=("/dev/$name  ($size)  ${model:-Unknown}")
  done < <(lsblk -d -n -o NAME,SIZE,TYPE,MODEL 2>/dev/null)

  if [[ ${#drives[@]} -eq 0 ]]; then
    error "No drives detected"
    exit 1
  fi

  local selected_label
  selected_label=$(printf '%s\n' "${labels[@]}" |
    gum choose \
      --header "  ⚠  Select Installation Drive  (ALL DATA WILL BE WIPED)" \
      --header.foreground 196 \
      --cursor "> ")

  local i
  for i in "${!labels[@]}"; do
    if [[ "${labels[$i]}" == "$selected_label" ]]; then
      DRIVE="${drives[$i]}"
      break
    fi
  done

  [[ -b "$DRIVE" ]] || {
    error "Invalid drive: $DRIVE"
    exit 1
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Menu-driven configuration (archinstall-style)
# ─────────────────────────────────────────────────────────────────────────────
configure() {
  while true; do
    clear
    print_banner

    local pw_display="${USER_PASSWORD:+[set]}"
    pw_display="${pw_display:-not set}"

    local menu_items=(
      "  Hostname      ›  ${HOSTNAME:-not set}"
      "  Username      ›  ${USERNAME:-not set}"
      "  Password      ›  ${pw_display}"
      "  Locale        ›  ${LOCALE}"
      "  Timezone      ›  ${TIMEZONE}"
      "  Keyboard      ›  ${KEYBOARD}"
      "  Mirror        ›  ${MIRROR_REGION}"
      "  GPU Driver    ›  ${GPU_DRIVER}"
      "  Drive         ›  ${DRIVE:-not set}"
      "  ─────────────────────────────────"
      "  ✓  Start Installation"
    )

    local choice
    choice=$(printf '%s\n' "${menu_items[@]}" |
      gum choose \
        --header "  ↑↓ Navigate   Enter = Select   (set all fields before installing)" \
        --header.foreground 99 \
        --cursor "> " \
        --height 20)

    case "$choice" in
    *Hostname*) ask_hostname ;;
    *Username*) ask_username ;;
    *Password*) ask_password ;;
    *Locale*) ask_locale ;;
    *Timezone*) ask_timezone ;;
    *Keyboard*) ask_keyboard ;;
    *Mirror*) ask_mirror ;;
    *"GPU Driver"*) ask_gpu ;;
    *Drive*) ask_drive ;;
    *"Start Installation"*)
      if [[ -z "$HOSTNAME" || -z "$USERNAME" || -z "$USER_PASSWORD" || -z "$DRIVE" ]]; then
        warn "Please set Hostname, Username, Password, and Drive before continuing"
        sleep 2
        continue
      fi
      return 0
      ;;
    *──*) continue ;;
    esac
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary & confirmation
# ─────────────────────────────────────────────────────────────────────────────
show_summary() {
  clear
  gum style \
    --border double \
    --border-foreground 196 \
    --padding "1 3" \
    --margin "1 2" \
    "  ⚠  FINAL REVIEW — ALL DATA ON  $DRIVE  WILL BE LOST  ⚠  " \
    "" \
    "  Hostname    :  $HOSTNAME" \
    "  Username    :  $USERNAME" \
    "  Drive       :  $DRIVE" \
    "  Locale      :  $LOCALE" \
    "  Timezone    :  $TIMEZONE" \
    "  Keyboard    :  $KEYBOARD" \
    "  Mirror      :  $MIRROR_REGION" \
    "  GPU Driver  :  $GPU_DRIVER" \
    "  Kernel      :  linux-zen" \
    "  Bootloader  :  GRUB (EFI)" \
    "  Desktop     :  Hyprland + SDDM"

  echo ""
  gum confirm \
    --default=false \
    --affirmative "  ✓ Install Now  " \
    --negative "  ← Go Back  " \
    "Proceed with installation?"
}

# ─────────────────────────────────────────────────────────────────────────────
# Installation steps
# ─────────────────────────────────────────────────────────────────────────────

partition() {
  info "Partitioning $DRIVE..."

  wipefs -af "$DRIVE" 2>/dev/null || true
  dd if=/dev/zero of="$DRIVE" bs=512 count=34 2>/dev/null || true

  parted -s "$DRIVE" mklabel gpt
  parted -s "$DRIVE" mkpart ESP fat32 1MiB 513MiB
  parted -s "$DRIVE" set 1 boot on
  parted -s "$DRIVE" set 1 esp on
  parted -s "$DRIVE" mkpart primary ext4 513MiB 100%

  sleep 1
  partprobe "$DRIVE" 2>/dev/null || true
  sleep 1

  if [[ "$DRIVE" =~ nvme|mmcblk ]]; then
    PART_BOOT="${DRIVE}p1"
    PART_ROOT="${DRIVE}p2"
  else
    PART_BOOT="${DRIVE}1"
    PART_ROOT="${DRIVE}2"
  fi

  mkfs.fat -F 32 -n BOOT "$PART_BOOT"
  mkfs.ext4 -F -L ROOT "$PART_ROOT"

  mount "$PART_ROOT" /mnt
  mkdir -p /mnt/boot
  mount "$PART_BOOT" /mnt/boot

  ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$PART_ROOT")
  success "Partitions created and mounted"
}

install_base() {
  info "Updating mirrors for region: $MIRROR_REGION..."
  pacman -Sy --noconfirm reflector 2>/dev/null || true
  reflector \
    --country "$MIRROR_REGION" \
    --protocol https \
    --sort rate \
    --fastest 10 \
    --age 24 \
    --save /etc/pacman.d/mirrorlist 2>/dev/null ||
    warn "Mirror ranking failed, using defaults"

  # GPU packages — use DKMS variants for linux-zen compatibility
  local gpu_packages=()
  case "$GPU_DRIVER" in
  nvidia)
    # FIX: 'nvidia' only works with stock kernel; use nvidia-dkms for linux-zen
    gpu_packages=(nvidia-dkms nvidia-utils nvidia-settings lib32-nvidia-utils)
    ;;
  nvidia-open)
    gpu_packages=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils)
    ;;
  amdgpu)
    gpu_packages=(mesa xf86-video-amdgpu vulkan-radeon lib32-mesa lib32-vulkan-radeon)
    ;;
  intel)
    gpu_packages=(mesa xf86-video-intel intel-media-driver vulkan-intel lib32-mesa lib32-vulkan-intel)
    ;;
  *)
    gpu_packages=(mesa)
    ;;
  esac

  local base_packages=(
    base base-devel
    linux-zen linux-zen-headers linux-firmware # headers needed for DKMS modules
    sudo vim neovim git curl wget
    networkmanager
    efibootmgr grub os-prober
    reflector
  )

  info "Installing base system (this may take a while)..."
  pacstrap -K /mnt "${base_packages[@]}" "${gpu_packages[@]}"

  genfstab -U /mnt >/mnt/etc/fstab
  success "Base system installed"
}

copy_network() {
  info "Copying network configuration..."
  # Copy iwd wifi profiles if present (from live environment)
  if [[ -d /var/lib/iwd ]]; then
    mkdir -p /mnt/var/lib/iwd
    cp /var/lib/iwd/*.psk /mnt/var/lib/iwd/ 2>/dev/null || true
  fi

  # Enable NetworkManager in the new install
  arch-chroot /mnt systemctl enable NetworkManager
  success "Network configured"
}

configure_system() {
  info "Configuring system..."

  arch-chroot /mnt bash -euo pipefail <<CHROOT
set -e

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
sed -i "/^#${LOCALE}/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Console keyboard
echo "KEYMAP=${KEYBOARD}" > /etc/vconsole.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname

# Hosts file
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# Pacman tweaks
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i '/^#Color$/s/^#//' /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || echo "ILoveCandy" >> /etc/pacman.conf

# Enable multilib (for 32-bit support)
grep -q "\[multilib\]" /etc/pacman.conf || cat >> /etc/pacman.conf <<'MULTILIB'
[multilib]
Include = /etc/pacman.d/mirrorlist
MULTILIB

# Wheel group sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

CHROOT

  success "System configured"
}

create_users() {
  info "Creating users..."
  arch-chroot /mnt useradd -m -G wheel,input,audio,video,lp,storage -s /bin/bash "$USERNAME" 2>/dev/null || true
  echo "${USERNAME}:${USER_PASSWORD}" | chpasswd -R /mnt
  echo "root:${ROOT_PASSWORD}" | chpasswd -R /mnt
  success "Users created"
}

install_packages() {
  info "Installing Hyprland and desktop packages..."

  arch-chroot /mnt bash -euo pipefail <<'CHROOT'
set -e
pacman -Sy --noconfirm

pacman -S --noconfirm --needed \
    pipewire pipewire-alsa pipewire-jack pipewire-pulse \
    wireplumber gst-plugin-pipewire libpulse \
    bluez bluez-utils \
    hyprland dunst kitty uwsm wofi dolphin \
    xdg-desktop-portal-hyprland \
    qt5-wayland qt6-wayland \
    polkit-kde-agent grim slurp \
    sddm \
    btop fastfetch \
    zram-generator \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji

systemctl enable bluetooth
systemctl enable sddm
CHROOT

  success "Desktop packages installed"
}

setup_swap() {
  info "Configuring zram swap..."
  arch-chroot /mnt bash -euo pipefail <<'CHROOT'
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
systemctl enable systemd-zram-setup@zram0.service
CHROOT
  success "Swap configured"
}

setup_mirrors_persistent() {
  info "Setting up reflector for mirror maintenance..."
  cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

  arch-chroot /mnt bash -euo pipefail <<CHROOT
mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf <<EOF
--country "${MIRROR_REGION}"
--protocol https
--sort rate
--fastest 10
--age 24
--save /etc/pacman.d/mirrorlist
EOF
systemctl enable reflector.timer
CHROOT

  success "Mirror maintenance configured"
}

install_bootloader() {
  info "Installing GRUB bootloader..."

  arch-chroot /mnt bash -euo pipefail <<'CHROOT'
grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot \
    --bootloader-id=GRUB \
    --recheck

grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

  success "GRUB installed"
}

cleanup() {
  info "Syncing and unmounting..."
  sync
  umount -R /mnt 2>/dev/null || true
  success "Done"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
  check_root
  check_arch
  install_gum
  print_banner

  # Menu-driven config (archinstall-style — keep looping until user is satisfied)
  configure

  # Show summary; go back to menu if user cancels
  while true; do
    show_summary && break
    configure
  done

  # ── Installation ──────────────────────────────────────────────────────────
  clear
  gum style \
    --border thick \
    --border-foreground 99 \
    --padding "1 3" \
    "  ⚙  Starting installation…  "
  echo ""

  partition
  install_base
  copy_network
  configure_system
  create_users
  install_packages
  setup_swap
  setup_mirrors_persistent
  install_bootloader
  cleanup

  # ── Done ──────────────────────────────────────────────────────────────────
  echo ""
  gum style \
    --border double \
    --border-foreground 76 \
    --padding "1 4" \
    --margin "1 2" \
    "  ✅  Installation Complete!  " \
    "" \
    "  Remove the USB drive, then reboot:" \
    "  systemctl reboot"
}

main "$@"
