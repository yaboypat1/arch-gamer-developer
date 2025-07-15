# Arch Gamer Developer Installer

A robust, automated Arch Linux installation script for gamers and developers. Supports:
- KDE Plasma desktop
- NVIDIA/AMD/Intel detection
- Gaming, dev, virtualization, and AI packages
- Timezone/locale auto-detection (with fallback)
- VirtualBox guest tools (auto-detect)
- UEFI (systemd-boot) and BIOS (GRUB) bootloader
- Error handling and user feedback

## How to Use This Script

### Requirements
- Arch Linux official ISO (latest recommended)
- Internet connection
- A blank disk or VM disk (all data will be erased)
- Familiarity with basic Linux terminal commands

### Preparation
1. **Boot from the Arch Linux ISO**
   - In VirtualBox: attach the ISO and boot the VM.
   - On real hardware: boot from USB/DVD.
2. **Connect to the Internet**
   - Wired: usually works out of the box.
   - Wi-Fi: use `iwctl` to connect (see Arch Wiki for details).

### Download the Script
You can download the script using `git` or `curl`:

**Option 1: Using git**
```sh
git clone https://github.com/yaboypat1/arch-gamer-developer.git
cd arch-gamer-developer
```

**Option 2: Using curl**
```sh
curl -LO https://raw.githubusercontent.com/yaboypat1/arch-gamer-developer/main/install_arch_gamer_developer.sh
chmod +x install_arch_gamer_developer.sh
```

### Edit Configuration
Before running the script, edit these variables at the top:
- `TARGET_DISK` (e.g. `/dev/sda`, `/dev/nvme0n1`)
- `SWAP_SIZE` (e.g. `16G`)
- `HOSTNAME`, `USERNAME`, `PASSWORD`, `ROOT_PASSWORD`

Edit with:
```sh
nano install_arch_gamer_developer.sh
```

### Run the Script
Run as root:
```sh
bash install_arch_gamer_developer.sh
```

The script will:
- Partition and format your disk
- Install Arch Linux with KDE Plasma, dev/gaming/AI tools
- Set up timezone/locale automatically (with fallback)
- Detect and install NVIDIA drivers if needed
- Detect VirtualBox and install guest tools if needed
- Set up GRUB or systemd-boot depending on BIOS/UEFI

### After Installation
- Reboot the system:
  ```sh
  reboot
  ```
- Remove the ISO from the VM or your USB/DVD from hardware
- Log in with your configured username and password

---

## Troubleshooting
- If you see errors about partitions being in use, reboot and try again.
- For UEFI boot issues in VirtualBox, try adding `nomodeset` to the boot parameters.
- For network issues, check your connection and `/etc/resolv.conf`.

---

## Notes
- All data on the target disk will be erased!
- The script is designed for clean installs only.
- See the script comments for advanced configuration options.

---

## Notes
- For VirtualBox, guest additions are installed automatically.
- For UEFI systems, systemd-boot is used; for BIOS, GRUB is used.
- Timezone/locale is auto-detected if internet is available, otherwise defaults to Ontario, Canada.
- All package groups are Arch Linux official packages.

## Contributing
Pull requests and suggestions are welcome!

## License
MIT
