#!/usr/bin/env python3
"""
Arch Linux Installation Script
Based on archinstall library with Hyprland, pipewire, and custom post-install
"""

import os
import sys
from pathlib import Path
from typing import Optional

from archinstall.default_profiles.desktops.hyprland import HyprlandProfile
from archinstall.lib.applications.application_handler import ApplicationHandler
from archinstall.lib.applications.audio import AudioApp
from archinstall.lib.applications.bluetooth import BluetoothApp
from archinstall.lib.args import ArchConfigHandler
from archinstall.lib.disk.device_handler import device_handler
from archinstall.lib.disk.filesystem import FilesystemHandler
from archinstall.lib.disk.utils import disk_layouts
from archinstall.lib.hardware import GfxDriver, SysInfo
from archinstall.lib.installer import Installer
from archinstall.lib.mirror.mirror_handler import MirrorListHandler
from archinstall.lib.models import (
    Audio,
    AudioConfiguration,
    BluetoothConfiguration,
    Bootloader,
    DeviceModification,
    DiskLayoutConfiguration,
    DiskLayoutType,
    EncryptionType,
    FilesystemType,
    ModificationStatus,
    NetworkConfiguration,
    NicType,
    PartitionFlag,
    PartitionModification,
    PartitionType,
    ProfileConfiguration,
    Size,
    Unit,
    User,
)
from archinstall.lib.models.application import ZramAlgorithm
from archinstall.lib.models.locale import LocaleConfiguration
from archinstall.lib.models.mirrors import MirrorConfiguration, MirrorRegion
from archinstall.lib.models.network import Nic
from archinstall.lib.models.users import Password
from archinstall.lib.network.network_handler import install_network_config
from archinstall.lib.output import debug, error, info, warn
from archinstall.lib.profile.profiles_handler import profile_handler


class ArchInstaller:
    def __init__(
        self,
        hostname: str,
        username: str,
        user_password: str,
        root_password: Optional[str] = None,
        locale: str = 'en_US.UTF-8',
        timezone: str = 'America/New_York',
        keyboard_layout: str = 'us',
        mirror_region: Optional[str] = None,
        drive_path: str = '/dev/sda',
        wipe_drive: bool = True,
        gpu_driver: Optional[str] = None,
        kernel: str = 'linux',
    ):
        self.hostname = hostname
        self.username = username
        self.user_password = user_password
        self.root_password = root_password or user_password
        self.locale = locale
        self.timezone = timezone
        self.keyboard_layout = keyboard_layout
        self.mirror_region = mirror_region
        self.drive_path = Path(drive_path)
        self.wipe_drive = wipe_drive
        self.kernel = kernel

        if gpu_driver:
            self.gpu_driver = GfxDriver(gpu_driver)
        else:
            self.gpu_driver = self._detect_gpu_driver()

        self.mountpoint = Path('/mnt')
        self.disk_config: Optional[DiskLayoutConfiguration] = None

    def _detect_gpu_driver(self) -> GfxDriver:
        if SysInfo.has_nvidia_graphics():
            info('Detected NVIDIA GPU, using proprietary driver')
            return GfxDriver.NvidiaProprietary
        elif SysInfo.has_amd_graphics():
            info('Detected AMD GPU, using open-source driver')
            return GfxDriver.AmdOpenSource
        elif SysInfo.has_intel_graphics():
            info('Detected Intel GPU, using open-source driver')
            return GfxDriver.IntelOpenSource
        else:
            info('No dedicated GPU detected, using all open-source drivers')
            return GfxDriver.AllOpenSource

    def _get_gpu_packages(self) -> list[str]:
        packages = []
        for pkg in self.gpu_driver.gfx_packages():
            packages.append(pkg.value)
        return packages

    def _setup_disk_config(self) -> DiskLayoutConfiguration:
        device = device_handler.get_device(self.drive_path)
        if not device:
            raise ValueError(f'No device found at {self.drive_path}')

        device_modification = DeviceModification(device, wipe=self.wipe_drive)

        boot_partition = PartitionModification(
            status=ModificationStatus.Create,
            type=PartitionType.Primary,
            start=Size(1, Unit.MiB, device.device_info.sector_size),
            length=Size(512, Unit.MiB, device.device_info.sector_size),
            mountpoint=Path('/boot'),
            fs_type=FilesystemType.Fat32,
            flags=[PartitionFlag.BOOT, PartitionFlag.ESP],
        )
        device_modification.add_partition(boot_partition)

        root_partition = PartitionModification(
            status=ModificationStatus.Create,
            type=PartitionType.Primary,
            start=Size(513, Unit.MiB, device.device_info.sector_size),
            length=Size(50, Unit.GiB, device.device_info.sector_size),
            mountpoint=Path('/'),
            fs_type=FilesystemType.Ext4,
            mount_options=[],
        )
        device_modification.add_partition(root_partition)

        start_home = root_partition.start + root_partition.length
        length_home = device.device_info.total_size - (start_home - device.device_info.sector_size)

        if length_home >= Size(10, Unit.GiB, device.device_info.sector_size):
            home_partition = PartitionModification(
                status=ModificationStatus.Create,
                type=PartitionType.Primary,
                start=start_home,
                length=length_home,
                mountpoint=Path('/home'),
                fs_type=FilesystemType.Ext4,
                mount_options=[],
            )
            device_modification.add_partition(home_partition)

        disk_config = DiskLayoutConfiguration(
            config_type=DiskLayoutType.Default,
            device_modifications=[device_modification],
        )
        return disk_config

    def _setup_mirror_config(self) -> MirrorConfiguration:
        if self.mirror_region:
            return MirrorConfiguration(
                custom_mirrors=[],
                regions=[MirrorRegion(self.mirror_region)],
            )
        return MirrorConfiguration(
            custom_mirrors=[],
            regions=[MirrorRegion('United_States')],
        )

    def run(self) -> bool:
        try:
            info(f'Starting Arch Linux installation for {self.hostname}')

            self.disk_config = self._setup_disk_config()

            mirror_config = self._setup_mirror_config()
            mirror_handler = MirrorListHandler(offline=False)

            fs_handler = FilesystemHandler(self.disk_config)
            info(f'Creating partitions on {self.drive_path}...')
            fs_handler.perform_filesystem_operations()

            with Installer(
                self.mountpoint,
                self.disk_config,
                kernels=[self.kernel],
            ) as installation:
                installation.mount_ordered_layout()
                installation.sanity_check()

                installation.set_mirrors(mirror_handler, mirror_config, on_target=False)

                locale_config = LocaleConfiguration(
                    sys_lang=self.locale,
                    sys_enc='UTF-8',
                    kb_layout=self.keyboard_layout,
                )

                installation.minimal_installation(
                    optional_repositories=[],
                    mkinitcpio=True,
                    hostname=self.hostname,
                    locale_config=locale_config,
                )

                installation.set_mirrors(mirror_handler, mirror_config, on_target=True)

                installation.setup_swap(algo=ZramAlgorithm.ZSTD)

                installation.add_bootloader(Bootloader.Grub, uki=False, removable=False)

                network_config = NetworkConfiguration(
                    type=NicType.ISO,
                    nics=[],
                )
                install_network_config(network_config, installation, None)

                root_user = User('root', Password(plaintext=self.root_password), False)
                installation.set_user_password(root_user)

                user = User(
                    self.username,
                    Password(plaintext=self.user_password),
                    True,
                )
                installation.create_users(user)

                audio_config = AudioConfiguration(audio=Audio.PIPEWIRE)
                audio_app = AudioApp()
                audio_app.install(installation, audio_config, [user])

                bluetooth_config = BluetoothConfiguration(enable=True)
                bluetooth_app = BluetoothApp()
                bluetooth_app.install(installation)

                profile_config = ProfileConfiguration(HyprlandProfile())
                profile_handler.install_profile_config(installation, profile_config)

                gpu_packages = self._get_gpu_packages()
                if gpu_packages:
                    installation.add_additional_packages(gpu_packages)

                hyprland_profile = HyprlandProfile()
                hyprland_profile.post_install(installation)
                hyprland_profile.provision(installation, [user])

                installation.set_timezone(self.timezone)
                installation.activate_time_synchronization()

                self._run_chroot_post_install(installation)

                installation.genfstab()

                info(f'Installation completed for {self.hostname}!')
                info(f'Log files available at /var/log/archinstall/')
                return True

        except Exception as e:
            error(f'Installation failed: {e}')
            import traceback
            traceback.print_exc()
            return False

    def _run_chroot_post_install(self, installation: Installer) -> None:
        info('Setting up post-installation script for first boot...')

        script = '''#!/bin/bash
set -e

REPO="dhms013/dhmsDots"
export DOTFILES_DIR="$HOME/.dhmsDots"
SCRIPTS_DIR="$DOTFILES_DIR/packages/scripts"

sudo -v

if [ -d "$DOTFILES_DIR" ]; then
    echo "==> Updating existing dotfiles repo"
    git -C "$DOTFILES_DIR" pull
else
    echo "==> Cloning dhmsDots"
    git clone --depth=1 "https://github.com/$REPO.git" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

[ -f "$SCRIPTS_DIR/logo.sh" ] && bash "$SCRIPTS_DIR/logo.sh"
[ -f "$SCRIPTS_DIR/resolver.sh" ] && bash "$SCRIPTS_DIR/resolver.sh"
sudo usermod -aG input "${USER}"
[ -f "$SCRIPTS_DIR/install.sh" ] && bash "$SCRIPTS_DIR/install.sh"
[ -f "$SCRIPTS_DIR/uninstall.sh" ] && bash "$SCRIPTS_DIR/uninstall.sh"
[ -f "$SCRIPTS_DIR/dotfiles.sh" ] && bash "$SCRIPTS_DIR/dotfiles.sh"
[ -f "$SCRIPTS_DIR/dirs.sh" ] && bash "$SCRIPTS_DIR/dirs.sh"
[ -f "$SCRIPTS_DIR/sddm.sh" ] && bash "$SCRIPTS_DIR/sddm.sh"
[ -f "$SCRIPTS_DIR/defaults.sh" ] && bash "$SCRIPTS_DIR/defaults.sh"
[ -f "$SCRIPTS_DIR/theme.sh" ] && bash "$SCRIPTS_DIR/theme.sh"
[ -f "$SCRIPTS_DIR/services.sh" ] && bash "$SCRIPTS_DIR/services.sh"

rm -f "$HOME/.config/autostart/post_install.desktop"
exit 0
'''

        autostart_dir = self.mountpoint / 'home' / self.username / '.config' / 'autostart'
        autostart_dir.mkdir(parents=True, exist_ok=True)

        desktop_entry = f'''[Desktop Entry]
Type=Application
Name=Post Install
Exec=bash -c '{script}'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
'''

        desktop_file = autostart_dir / 'post_install.desktop'
        desktop_file.write_text(desktop_entry)

        script_file = self.mountpoint / 'tmp' / 'post_install.sh'
        script_file.write_text(script)
        script_file.chmod(0o755)

        info('Post-install will run automatically on first login')


def select_gpu_driver() -> Optional[str]:
    print('\n=== GPU Driver Selection ===')
    print('1. Auto-detect (Recommended)')
    print('2. NVIDIA (Proprietary)')
    print('3. NVIDIA (Open Kernel)')
    print('4. AMD/ATI (Open Source)')
    print('5. Intel (Open Source)')
    print('6. All Open Source')
    print('7. No GPU packages')

    choice = input('Select GPU driver [1]: ').strip()

    drivers = {
        '1': None,
        '2': 'Nvidia (proprietary)',
        '3': 'Nvidia (open kernel module for newer GPUs, Turing+)',
        '4': 'AMD / ATI (open-source)',
        '5': 'Intel (open-source)',
        '6': 'All open-source',
        '7': None,
    }

    return drivers.get(choice, None)


def select_mirror_region() -> Optional[str]:
    print('\n=== Mirror Region Selection ===')
    print('Available regions (or press Enter for United States):')

    regions = [
        'United_States', 'Canada', 'Mexico', 'Brazil', 'Colombia',
        'Argentina', 'Chile', 'Peru', 'United_Kingdom', 'Germany',
        'France', 'Netherlands', 'Spain', 'Sweden', 'Russia',
        'Poland', 'Japan', 'China', 'Taiwan', 'Singapore',
        'Australia', 'New_Zealand', 'India', 'Indonesia', 'Thailand',
    ]

    for i, region in enumerate(regions, 1):
        print(f'{i}. {region}')

    choice = input('Select region number or enter name: ').strip()

    if not choice:
        return 'United_States'

    if choice.isdigit():
        idx = int(choice) - 1
        if 0 <= idx < len(regions):
            return regions[idx]

    for region in regions:
        if region.lower().replace('_', ' ') == choice.lower().replace('_', ' '):
            return region

    return choice if choice else 'United_States'


def select_timezone() -> str:
    print('\n=== Timezone Selection ===')
    print('Enter timezone (e.g., America/New_York, Europe/London, Asia/Tokyo)')
    print('Or press Enter for America/New_York')

    timezone = input('Timezone: ').strip()
    return timezone or 'America/New_York'


def select_locale() -> str:
    print('\n=== Locale Selection ===')
    print('Enter locale (e.g., en_US.UTF-8, de_DE.UTF-8, ja_JP.UTF-8)')
    print('Or press Enter for en_US.UTF-8')

    locale = input('Locale: ').strip()
    return locale or 'en_US.UTF-8'


def select_keyboard() -> str:
    print('\n=== Keyboard Layout ===')
    print('Common layouts: us, uk, de, fr, es, jp, br')
    print('Or press Enter for us')

    layout = input('Keyboard layout: ').strip()
    return layout or 'us'


def list_drives() -> list[str]:
    print('\n=== Available Drives ===')
    import subprocess
    result = subprocess.run(['lsblk', '-d', '-n', '-o', 'NAME,SIZE,TYPE,MODEL'], 
                          capture_output=True, text=True)
    print(result.stdout)
    return result.stdout.strip().split('\n')


def main():
    print('=' * 50)
    print('  Arch Linux Installer (Hyprland Edition)')
    print('=' * 50)

    hostname = input('\nEnter hostname [archlinux]: ').strip()
    hostname = hostname or 'archlinux'

    username = input('Enter username [arch]: ').strip()
    username = username or 'arch'

    user_password = ''
    while not user_password:
        import getpass
        user_password = getpass.getpass('Enter user password: ')
        if not user_password:
            print('Password cannot be empty')

    root_password = getpass.getpass('Enter root password (or press Enter to use same as user): ')
    if not root_password:
        root_password = user_password

    locale = select_locale()
    timezone = select_timezone()
    keyboard_layout = select_keyboard()
    mirror_region = select_mirror_region()
    gpu_driver = select_gpu_driver()

    list_drives()
    drive_path = input('\nEnter drive path [/dev/sda]: ').strip()
    drive_path = drive_path or '/dev/sda'

    wipe = input('Wipe drive completely? [Y/n]: ').strip().lower()
    wipe_drive = wipe != 'n'

    kernel = input('Select kernel [linux]: ').strip()
    kernel = kernel or 'linux'

    print('\n' + '=' * 50)
    print('  Installation Summary')
    print('=' * 50)
    print(f'  Hostname:      {hostname}')
    print(f'  Username:      {username}')
    print(f'  Drive:         {drive_path}')
    print(f'  Wipe:          {"Yes" if wipe_drive else "No"}')
    print(f'  Locale:        {locale}')
    print(f'  Timezone:      {timezone}')
    print(f'  Keyboard:      {keyboard_layout}')
    print(f'  Mirror:        {mirror_region}')
    print(f'  GPU Driver:    {gpu_driver or "Auto-detect"}')
    print(f'  Kernel:        {kernel}')
    print('=' * 50)

    confirm = input('\nProceed with installation? [y/N]: ').strip().lower()
    if confirm != 'y':
        print('Installation cancelled')
        sys.exit(0)

    installer = ArchInstaller(
        hostname=hostname,
        username=username,
        user_password=user_password,
        root_password=root_password,
        locale=locale,
        timezone=timezone,
        keyboard_layout=keyboard_layout,
        mirror_region=mirror_region,
        drive_path=drive_path,
        wipe_drive=wipe_drive,
        gpu_driver=gpu_driver,
        kernel=kernel,
    )

    success = installer.run()

    if success:
        print('\nInstallation completed successfully!')
        print('You can now reboot and enjoy your new Arch Linux system.')
    else:
        print('\nInstallation failed. Please check the logs.')
        sys.exit(1)


if __name__ == '__main__':
    main()
