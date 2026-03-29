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
LOCALE=""
TIMEZONE=""
KEYBOARD=""
GPU_DRIVER=""
DRIVE=""
PART_BOOT=""
PART_ROOT=""
ROOT_PARTUUID=""

DOTS_URL="https://raw.githubusercontent.com/dhms013/dhmsDots/main/install.sh"

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
  echo "[INFO] Refreshing keyring..."
  pacman -Sy --noconfirm archlinux-keyring
  echo "[INFO] Installing gum..."
  pacman -S --noconfirm gum
  success "gum installed"
}

# ─── GPU hint (detect only, NOT a decision) ───────────────────────────────────
detect_gpu_hint() {
  if lspci 2>/dev/null | grep -qi nvidia; then
    echo "NVIDIA"
  elif lspci 2>/dev/null | grep -qi " amd\| ati\|radeon"; then
    echo "AMD"
  elif lspci 2>/dev/null | grep -qi intel; then
    echo "Intel"
  else
    echo "Unknown"
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
# Individual prompts
# ─────────────────────────────────────────────────────────────────────────────

ask_hostname() {
  HOSTNAME=$(gum input \
    --placeholder "e.g. archlinux" \
    --header "  Hostname" \
    --header.foreground 99 \
    --prompt "> " \
    --value "${HOSTNAME:-}")
}

ask_username() {
  USERNAME=$(gum input \
    --placeholder "e.g. arch" \
    --header "  Username" \
    --header.foreground 99 \
    --prompt "> " \
    --value "${USERNAME:-}")
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
    --placeholder "Leave empty to use same as user password" \
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
      --cursor "> ")
}

ask_timezone() {
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
      --cursor "> ")

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
      --cursor "> ")
}

ask_gpu() {
  local gpu_hint
  gpu_hint=$(detect_gpu_hint)

  local gpu_options=(
    "All open-source drivers (default)   ← mesa + all xf86 drivers"
    "AMD / ATI   — amdgpu + vulkan-radeon"
    "Intel       — intel  + vulkan-intel"
    "NVIDIA      — nvidia-open-dkms  (open kernel)"
    "NVIDIA      — nvidia-dkms       (proprietary)"
  )

  local choice
  choice=$(printf '%s\n' "${gpu_options[@]}" |
    gum choose \
      --header "  Select GPU Driver  [detected: $gpu_hint]" \
      --header.foreground 99 \
      --cursor "> ")

  case "$choice" in
  *"nvidia-dkms       (proprietary)"*) GPU_DRIVER="nvidia" ;;
  *"nvidia-open-dkms"*) GPU_DRIVER="nvidia-open" ;;
  *"amdgpu"*) GPU_DRIVER="amdgpu" ;;
  *"intel"*) GPU_DRIVER="intel" ;;
  *) GPU_DRIVER="all-open" ;;
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
    labels+=("/dev/$name  [$size]  ${model:-Unknown}")
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
      "  Hostname      ›  ${HOSTNAME:-⚠ not set}"
      "  Username      ›  ${USERNAME:-⚠ not set}"
      "  Password      ›  ${pw_display}"
      "  Locale        ›  ${LOCALE:-⚠ not set}"
      "  Timezone      ›  ${TIMEZONE:-⚠ not set}"
      "  Keyboard      ›  ${KEYBOARD:-⚠ not set}"
      "  GPU Driver    ›  ${GPU_DRIVER:-⚠ not set}"
      "  Drive         ›  ${DRIVE:-⚠ not set}"
      "  ─────────────────────────────────────────────"
      "  ✓  Start Installation"
    )

    local choice
    choice=$(printf '%s\n' "${menu_items[@]}" |
      gum choose \
        --header "  ↑↓ Navigate   Enter = Select   (all ⚠ fields must be set)" \
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
    *"GPU Driver"*) ask_gpu ;;
    *Drive*) ask_drive ;;
    *"Start Installation"*)
      local missing=()
      [[ -z "$HOSTNAME" ]] && missing+=("Hostname")
      [[ -z "$USERNAME" ]] && missing+=("Username")
      [[ -z "$USER_PASSWORD" ]] && missing+=("Password")
      [[ -z "$LOCALE" ]] && missing+=("Locale")
      [[ -z "$TIMEZONE" ]] && missing+=("Timezone")
      [[ -z "$KEYBOARD" ]] && missing+=("Keyboard")
      [[ -z "$GPU_DRIVER" ]] && missing+=("GPU Driver")
      [[ -z "$DRIVE" ]] && missing+=("Drive")

      if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Please set: ${missing[*]}"
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
    "  ⚠  FINAL REVIEW — ALL DATA ON $DRIVE WILL BE LOST  ⚠  " \
    "" \
    "  Hostname    :  $HOSTNAME" \
    "  Username    :  $USERNAME" \
    "  Drive       :  $DRIVE" \
    "  Locale      :  $LOCALE" \
    "  Timezone    :  $TIMEZONE" \
    "  Keyboard    :  $KEYBOARD" \
    "  GPU Driver  :  $GPU_DRIVER" \
    "  Kernel      :  linux-zen" \
    "  Bootloader  :  Limine (EFI)" \
    "  Desktop     :  Hyprland + SDDM" \
    "  Post-setup  :  dhmsDots (auto, in chroot)"

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
  local gpu_packages=()
  case "$GPU_DRIVER" in
  nvidia)
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
  all-open)
    gpu_packages=(
      mesa lib32-mesa
      xf86-video-amdgpu xf86-video-ati
      xf86-video-intel
      xf86-video-nouveau
      xf86-video-vesa
      vulkan-radeon vulkan-intel
    )
    ;;
  esac

  local base_packages=(
    base base-devel
    linux-zen linux-zen-headers linux-firmware
    sudo vim neovim git curl wget
    iwd
    efibootmgr limine
  )

  info "Installing base system (this may take a while)..."
  pacstrap -K /mnt "${base_packages[@]}" "${gpu_packages[@]}"

  genfstab -U /mnt >>/mnt/etc/fstab
  success "Base system installed"
}

copy_network() {
  info "Copying network configuration..."

  if [[ -d /var/lib/iwd ]]; then
    mkdir -p /mnt/var/lib/iwd
    cp /var/lib/iwd/*.psk /mnt/var/lib/iwd/ 2>/dev/null || true
  fi

  if [[ -d /etc/systemd/network ]]; then
    mkdir -p /mnt/etc/systemd/network
    cp /etc/systemd/network/* /mnt/etc/systemd/network/ 2>/dev/null || true
  fi

  arch-chroot /mnt systemctl enable iwd 2>/dev/null || true
  arch-chroot /mnt systemctl enable systemd-networkd 2>/dev/null || true
  arch-chroot /mnt systemctl enable systemd-resolved 2>/dev/null || true

  success "Network configuration copied"
}

configure_system() {
  info "Configuring system..."

  arch-chroot /mnt bash -euo pipefail <<CHROOT
set -e

ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

sed -i "/^#${LOCALE}/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "KEYMAP=${KEYBOARD}" > /etc/vconsole.conf

echo "${HOSTNAME}" > /etc/hostname

cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i '/^#Color\$/s/^#//' /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || echo "ILoveCandy" >> /etc/pacman.conf

grep -q "\[multilib\]" /etc/pacman.conf || cat >> /etc/pacman.conf <<'MULTILIB'
[multilib]
Include = /etc/pacman.d/mirrorlist
MULTILIB

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

install_limine() {
  info "Installing Limine bootloader..."

  # Derive disk and partition number from PART_BOOT for efibootmgr
  # e.g. /dev/sda1  → disk=/dev/sda,       part=1
  #      /dev/nvme0n1p1 → disk=/dev/nvme0n1, part=1
  local PART_NUM
  PART_NUM=$(echo "$PART_BOOT" | grep -o '[0-9]*$')

  local DISK
  if [[ "$DRIVE" =~ nvme|mmcblk ]]; then
    DISK="${PART_BOOT%p${PART_NUM}}"
  else
    DISK="${PART_BOOT%${PART_NUM}}"
  fi

  arch-chroot /mnt bash -euo pipefail <<CHROOT
set -e

# Deploy Limine EFI binary
mkdir -p /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/
cp /usr/share/limine/BOOTIA32.EFI /boot/EFI/limine/ 2>/dev/null || true

# Register Limine in NVRAM
efibootmgr \
    --create \
    --disk ${DISK} \
    --part ${PART_NUM} \
    --label "Arch Linux (Limine)" \
    --loader '\EFI\limine\BOOTX64.EFI' \
    --unicode

# Write limine.conf (new syntax: limine 8+)
cat > /boot/limine.conf <<'LIMINE_EOF'
timeout: 5
default_entry: 1

/Arch Linux
    protocol: linux
    path: boot():/vmlinuz-linux-zen
    cmdline: root=PARTUUID=ROOT_PARTUUID_PLACEHOLDER rw quiet
    module_path: boot():/initramfs-linux-zen.img

/Arch Linux (fallback initramfs)
    protocol: linux
    path: boot():/vmlinuz-linux-zen
    cmdline: root=PARTUUID=ROOT_PARTUUID_PLACEHOLDER rw
    module_path: boot():/initramfs-linux-zen-fallback.img
LIMINE_EOF

# Substitute the actual PARTUUID into the config
sed -i "s/ROOT_PARTUUID_PLACEHOLDER/${ROOT_PARTUUID}/g" /boot/limine.conf

# Pacman hook — auto-redeploy Limine EFI on package upgrade
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/limine.hook <<'HOOK_EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = limine

[Action]
Description = Deploying Limine EFI after upgrade...
When = PostTransaction
Exec = /bin/sh -c "cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/"
HOOK_EOF

CHROOT

  success "Limine installed"
}

run_post_install() {
  info "Running dhmsDots in chroot as $USERNAME..."

  arch-chroot /mnt sudo -u "${USERNAME}" bash -c \
    "curl -fsSL ${DOTS_URL} | bash" &&
    success "dhmsDots applied" ||
    {
      warn "dhmsDots chroot run failed — installing first-login fallback service"

      local service_dir="/mnt/home/${USERNAME}/.config/systemd/user"
      mkdir -p "$service_dir"

      cat >"${service_dir}/dhmsdots-install.service" <<SERVICE
[Unit]
Description=dhmsDots first-login installer
After=network-online.target
ConditionPathExists=%h/.config/systemd/user/dhmsdots-install.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'curl -fsSL ${DOTS_URL} | bash && systemctl --user disable dhmsdots-install.service && rm -f %h/.config/systemd/user/dhmsdots-install.service'
RemainAfterExit=yes

[Install]
WantedBy=default.target
SERVICE

      mkdir -p "${service_dir}/default.target.wants"
      ln -sf "../dhmsdots-install.service" \
        "${service_dir}/default.target.wants/dhmsdots-install.service"

      arch-chroot /mnt chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config"
      warn "dhmsDots will run automatically on first login as $USERNAME"
    }
}

cleanup() {
  info "Syncing and unmounting..."
  sync
  umount -R /mnt 2>/dev/null || true
  success "Cleanup done"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
  check_root
  check_arch
  install_gum
  print_banner

  configure

  while true; do
    show_summary && break
    configure
  done

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
  install_limine
  run_post_install
  cleanup

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
