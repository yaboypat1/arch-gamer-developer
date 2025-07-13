# Arch Gamer Developer Installer

A robust, automated Arch Linux installation script for gamers and developers. Supports:
- KDE Plasma desktop
- NVIDIA/AMD/Intel detection
- Gaming, dev, virtualization, and AI packages
- Timezone/locale auto-detection (with fallback)
- VirtualBox guest tools (auto-detect)
- UEFI (systemd-boot) and BIOS (GRUB) bootloader
- Error handling and user feedback

## Usage

1. **Edit configuration:**
   - Set `TARGET_DISK`, `SWAP_SIZE`, `HOSTNAME`, `USERNAME`, `PASSWORD`, `ROOT_PASSWORD` at the top of the script.
2. **Boot from Arch ISO and connect to the internet.**
3. **Copy the script to your live environment.**
4. **Run as root:**
   ```sh
   bash install_arch_gamer_developer.sh
   ```

## Notes
- For VirtualBox, guest additions are installed automatically.
- For UEFI systems, systemd-boot is used; for BIOS, GRUB is used.
- Timezone/locale is auto-detected if internet is available, otherwise defaults to Ontario, Canada.
- All package groups are Arch Linux official packages.

## Contributing
Pull requests and suggestions are welcome!

## License
MIT
