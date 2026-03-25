#!/bin/bash
# Step 02: Disk partitioning

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
