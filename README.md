# ⚠️ EXPERIMENTAL - USE AT YOUR OWN RISK ⚠️

---

## 🏹 dhmsInstall

> An opinionated Arch Linux installation script with Hyprland desktop environment.

This project provides an automated installation script for Arch Linux with Hyprland, pipewire, and essential desktop packages. Built on top of the `archinstall` library.

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
- **Bootloader**: Limine
- **Post-install**: Automatic dotfiles setup on first login

### Included Packages (from archinstall Hyprland profile)

```
hyprland, dunst, kitty, wofi, dolphin, xdg-desktop-portal-hyprland,
qt5-wayland, qt6-wayland, polkit-kde-agent, grim, slurp, sddm
```

---

## 🚀 How to Use

### From Arch Linux Live ISO

```bash
# Boot into Arch Linux live environment and run:
curl -fsSL https://raw.githubusercontent.com/dhms013/dhmsInstall/main/arch-hyprland-install.sh | bash
```

The script will:
1. Automatically install Python and archinstall (if not present)
2. Download and run the Python installer
3. Guide you through the installation process

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

On first login, the dotfiles installer will run automatically to set up your Hyprland environment with your preferred configurations.

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
├── arch-hyprland-install.sh   # Bootstrap script (for curl | bash)
└── arch-hyprland-install.py   # Python installer (uses archinstall)
```

---

## 🔗 Related

- [dhmsDots](https://github.com/dhms013/dhmsDots) - Post-install dotfiles and configurations
- [archinstall](https://github.com/archlinux/archinstall) - The installer library

---

## 📝 License

MIT License - See LICENSE file for details.
