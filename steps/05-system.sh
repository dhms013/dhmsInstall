#!/bin/bash
# Step 05: System configuration

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
