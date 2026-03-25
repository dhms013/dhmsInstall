#!/bin/bash
# Step 99: Cleanup

cleanup() {
    info "Cleaning up..."
    umount -R /mnt 2>/dev/null || true
    success "Cleanup completed"
}
