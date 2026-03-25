# ⚠️ EXPERIMENTAL - USE AT YOUR OWN RISK ⚠️

---

## 🏹 dhmsInstall

> An opinionated Arch Linux installation script with Hyprland desktop environment.

This project provides an automated installation script for Arch Linux with Hyprland, pipewire, and essential desktop packages. Uses `gum` for a modern TUI experience.

---

## ⚠️ Disclaimer

**This installer is EXPERIMENTAL and may cause data loss.**

- Always backup your important data before running
- The script wipes the selected drive by default
- Test in a virtual machine first
- The authors are not responsible for any damage

---

## 📋 Features

- **Desktop**: Hyprland (Wayland compositor)
- **Audio**: PipeWire with wireplumber
- **Bluetooth**: Bluez with bluetooth.service enabled
- **Network**: Copy from ISO setup (systemd-networkd + systemd-resolved)
- **Filesystem**: ext4 with zram swap
- **Kernel**: linux-zen
- **Bootloader**: Limine
- **Display Manager**: SDDM
- **Post-install**: dhmsDots runs in chroot during installation

### Default Packages

```
Hyprland Profile:
  hyprland, dunst, kitty, uwsm, dolphin, wofi,
  xdg-desktop-portal-hyprland, qt5-wayland, qt6-wayland,
  polkit-kde-agent, grim, slurp

Audio:
  pipewire, pipewire-alsa, pipewire-jack, pipewire-pulse,
  gst-plugin-pipewire, libpulse, wireplumber

Bluetooth:
  bluez, bluez-utils

System:
  sddm, linux-zen, limine
```

---

## 🚀 How to Use

### From Arch Linux Live ISO

```bash
# Boot into Arch Linux live environment and run:
curl -fsSL https://raw.githubusercontent.com/dhms013/dhmsDots/main/dhms-install.sh | bash
```

The script will:
1. Automatically install `gum` (if not present)
2. Guide you through the installation process with a modern TUI
3. Install all packages and configure your system
4. Run dhmsDots post-install in chroot

### What You'll Need to Configure

| Setting | Description |
|---------|-------------|
| Hostname | Your machine name |
| Username | Your login username |
| Passwords | User and root passwords |
| Locale | Language setting (default: en_US.UTF-8) |
| Timezone | Your timezone |
| Keyboard | Keyboard layout |
| GPU Driver | Auto-detect or manual selection |
| Drive | Target installation drive |

### After Installation

The dhmsDots installer runs automatically during installation (in chroot). After reboot, your Hyprland environment will be ready with your preferred configurations.

---

## 🔧 Requirements

- Arch Linux live environment ( booted from ISO )
- Internet connection
- Minimum 30GB free disk space
- UEFI system (for Limine bootloader)

---

## 📁 Project Structure

```
dhmsInstall/
├── README.md
└── dhms-install.sh            # Pure bash installer (single script)
```

---

## 🔗 Related

- [dhmsDots](https://github.com/dhms013/dhmsDots) - Post-install dotfiles and configurations
- [gum](https://github.com/charmbracelet/gum) - TUI tool for the installer

---

