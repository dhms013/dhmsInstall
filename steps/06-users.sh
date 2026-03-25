#!/bin/bash
# Step 06: User creation

create_users() {
    info "Creating users..."
    
    arch-chroot /mnt useradd -m -G wheel,input,audio,video,lp -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd -R /mnt
    echo "root:$ROOT_PASSWORD" | chpasswd -R /mnt
    
    success "Users created"
}
