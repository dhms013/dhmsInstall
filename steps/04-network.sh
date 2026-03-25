#!/bin/bash
# Step 04: Network configuration (copy from ISO)

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
