#!/bin/bash
# Step 09: Bootloader installation

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
