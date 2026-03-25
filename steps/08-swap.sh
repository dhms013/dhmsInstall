#!/bin/bash
# Step 08: Swap configuration

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
