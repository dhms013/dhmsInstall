#!/bin/bash
# Step 10: Post-installation

run_post_install() {
    info "Running post-installation..."
    
    arch-chroot /mnt bash -euo pipefail <<CHROOT
set -e

curl -fsSL ${POST_INSTALL_URL} | bash

CHROOT
    
    success "Post-installation completed"
}
