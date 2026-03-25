#!/bin/bash
# Step 01: Configuration prompts

detect_gpu() {
    if lspci | grep -qi nvidia; then
        GPU_DRIVER="nvidia"
    elif lspci | grep -qi amd; then
        GPU_DRIVER="amdgpu"
    elif lspci | grep -qi intel; then
        GPU_DRIVER="intel"
    else
        GPU_DRIVER="auto"
    fi
}

configure() {
    # Hostname
    HOSTNAME=$(gum_input "Hostname" "archlinux" "archlinux")
    : "${HOSTNAME:=archlinux}"
    
    # Username
    USERNAME=$(gum_input "Username" "arch" "arch")
    : "${USERNAME:=arch}"
    
    # User password
    USER_PASSWORD=$(gum_password "Password" "User password")
    while [[ -z "$USER_PASSWORD" ]]; do
        warn "Password cannot be empty"
        USER_PASSWORD=$(gum_password "Password" "User password")
    done
    
    # Root password
    ROOT_PASSWORD=$(gum_password "Root Password" "Root password (Enter for same)")
    : "${ROOT_PASSWORD:=$USER_PASSWORD}"
    
    # Locale
    locales=(
        "en_US.UTF-8" "en_GB.UTF-8" "en_AU.UTF-8"
        "de_DE.UTF-8" "de_AT.UTF-8" "de_CH.UTF-8"
        "fr_FR.UTF-8" "fr_CA.UTF-8"
        "es_ES.UTF-8" "es_MX.UTF-8"
        "pt_BR.UTF-8" "pt_PT.UTF-8"
        "it_IT.UTF-8"
        "ru_RU.UTF-8"
        "ja_JP.UTF-8"
        "zh_CN.UTF-8" "zh_TW.UTF-8"
        "ko_KR.UTF-8"
        "id_ID.UTF-8"
        "th_TH.UTF-8"
        "tr_TR.UTF-8"
        "pl_PL.UTF-8"
        "nl_NL.UTF-8"
    )
    
    LOCALE=$(gum_choose "Locale" "${locales[@]}")
    : "${LOCALE:=en_US.UTF-8}"
    
    # Timezone
    timezones=(
        "America/New_York" "America/Chicago" "America/Denver" "America/Los_Angeles"
        "America/Toronto" "America/Vancouver" "America/Mexico_City" "America/Sao_Paulo"
        "Europe/London" "Europe/Paris" "Europe/Berlin" "Europe/Madrid" "Europe/Rome"
        "Europe/Moscow" "Europe/Istanbul"
        "Asia/Tokyo" "Asia/Shanghai" "Asia/Hong_Kong" "Asia/Taipei" "Asia/Seoul"
        "Asia/Singapore" "Asia/Jakarta" "Asia/Bangkok"
        "Australia/Sydney" "Australia/Perth"
        "Pacific/Auckland"
    )
    
    TIMEZONE=$(gum_choose "Timezone" "${timezones[@]}")
    : "${TIMEZONE:=America/New_York}"
    
    # Keyboard
    keyboards=(
        "us" "us-acentos" "uk" "de" "de-latin1" "fr" "fr-latin9"
        "es" "pt" "it" "ru" "jp" "br" "dvorak"
    )
    
    KEYBOARD=$(gum_choose "Keyboard Layout" "${keyboards[@]}")
    : "${KEYBOARD:=us}"
    
    # Mirror region
    mirror_regions=(
        "United_States" "Canada" "Mexico" "Brazil" "Colombia"
        "Argentina" "Chile" "Peru" "United_Kingdom" "Germany"
        "France" "Netherlands" "Spain" "Sweden" "Russia"
        "Poland" "Japan" "China" "Taiwan" "Singapore"
        "Australia" "New_Zealand" "India" "Indonesia" "Thailand"
    )
    
    MIRROR_REGION=$(gum_choose "Mirror Region" "${mirror_regions[@]}")
    : "${MIRROR_REGION:=United_States}"
    
    # GPU driver
    GPU_CHOICE=$(gum_choose "GPU Driver" \
        "Auto-detect (Recommended)" \
        "NVIDIA (Proprietary)" \
        "NVIDIA (Open Kernel)" \
        "AMD/ATI (Open Source)" \
        "Intel (Open Source)")
    
    case "$GPU_CHOICE" in
        "NVIDIA (Proprietary)") GPU_DRIVER="nvidia" ;;
        "NVIDIA (Open Kernel)") GPU_DRIVER="nvidia-open" ;;
        "AMD/ATI (Open Source)") GPU_DRIVER="amdgpu" ;;
        "Intel (Open Source)") GPU_DRIVER="intel" ;;
        *) detect_gpu ;;
    esac
    
    # Drive selection
    echo ""
    gum style --border normal --padding "1" "Available Drives:"
    lsblk -d -n -o NAME,SIZE,TYPE,MODEL | awk '{print NR". /dev/"$1" ("$2", "$3")"}'
    
    local drive_count
    drive_count=$(lsblk -d -n -o NAME | wc -l)
    
    DRIVE_NUM=$(gum_input "Drive Number" "1" "1")
    : "${DRIVE_NUM:=1}"
    
    if [[ "$DRIVE_NUM" -lt 1 ]] || [[ "$DRIVE_NUM" -gt "$drive_count" ]]; then
        DRIVE_NUM=1
    fi
    
    DRIVE="/dev/$(lsblk -d -n -o NAME | sed -n "${DRIVE_NUM}p")"
    
    if [[ ! -b "$DRIVE" ]]; then
        error "Invalid drive selection"
        exit 1
    fi
    
    # Wipe confirmation
    WIPE_DRIVE=$(gum_confirm "Wipe drive completely?" "Yes, wipe drive" "No, keep data" false)
}

show_summary() {
    echo ""
    gum style --border double --padding "1 2" \
        " Installation Summary " \
        "" \
        "Hostname:     $HOSTNAME" \
        "Username:     $USERNAME" \
        "Drive:        $DRIVE" \
        "Wipe:         $([ "$WIPE_DRIVE" = true ] && echo "Yes" || echo "No")" \
        "Locale:       $LOCALE" \
        "Timezone:     $TIMEZONE" \
        "Keyboard:     $KEYBOARD" \
        "Mirror:       $MIRROR_REGION" \
        "GPU Driver:   $GPU_DRIVER" \
        "Kernel:       linux-zen"
    
    local confirm
    confirm=$(gum_confirm "Proceed with installation?" "Proceed" "Cancel" false)
    
    if [[ "$confirm" != "true" ]]; then
        info "Installation cancelled"
        exit 0
    fi
}
