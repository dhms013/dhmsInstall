#!/bin/bash
# Step 03: Base system installation

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
