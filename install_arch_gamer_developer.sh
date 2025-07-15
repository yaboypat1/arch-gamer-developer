#!/bin/bash
set -e

# Helper: Check command success
check_success() {
    if [ $? -ne 0 ]; then
        echo "❌ Error: $1" >&2
        exit 1
    fi
}


# === CONFIGURATION ===
TARGET_DISK="/dev/nvme0n1"  # Change this to match your disk
SWAP_SIZE="16G"            # Swap size (adjust as needed)
INSTALL_NVIDIA=true         # Set to false for AMD/Intel systems

# Warn if /mnt is already mounted
if mount | grep -qE " on /mnt( |$)"; then
    echo "⚠️  Warning: /mnt is already mounted. If this is from a previous install attempt, consider unmounting first (umount -A --recursive /mnt)."
fi

# Auto-disable NVIDIA in VirtualBox
if command -v dmidecode >/dev/null 2>&1; then
    IS_VBOX=$(grep -q "VirtualBox" /proc/scsi/scsi 2>/dev/null && echo 1 || dmidecode | grep -qi "VirtualBox" && echo 1 || echo 0)
else
    IS_VBOX=$(grep -q "VirtualBox" /proc/scsi/scsi 2>/dev/null && echo 1 || echo 0)
fi
if [ "$IS_VBOX" -eq 1 ]; then
    echo "VirtualBox detected: disabling NVIDIA package installation."
    INSTALL_NVIDIA=false
fi

# Detect partition suffix (p for NVMe, nothing for SATA)
if [[ "$TARGET_DISK" == *nvme* ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

# Convert SWAP_SIZE to MiB for parted math
if [[ "$SWAP_SIZE" == *G ]]; then
    SWAP_SIZE_MIB=$(( ${SWAP_SIZE%G} * 1024 ))
elif [[ "$SWAP_SIZE" == *M ]]; then
    SWAP_SIZE_MIB=${SWAP_SIZE%M}
else
    echo "Invalid SWAP_SIZE format. Use G or M (e.g., 16G)."
    exit 1
fi
ROOT_START_MIB=$((551 + SWAP_SIZE_MIB))

HOSTNAME="archgaming"      # Your hostname
USERNAME="pat"             # Your username
PASSWORD="coolpat14"    # Your password (change this!)
ROOT_PASSWORD="coolpat14"  # Root password (change this!)

# === PACKAGE GROUPS ===
PACKAGES_BASE="base base-devel linux linux-firmware intel-ucode sudo"

PACKAGES_DESKTOP="plasma-desktop plasma-wayland-protocols plasma-workspace sddm konsole dolphin plasma-pa plasma-nm powerdevil kscreen plasma-systemmonitor kde-gtk-config breeze-gtk xdg-desktop-portal-kde packagekit-qt5 kwallet-pam ksshaskpass kwalletmanager"

PACKAGES_NVIDIA="nvidia nvidia-utils nvidia-settings"

PACKAGES_GAMING="steam lutris wine gamemode discord"

PACKAGES_DEVELOPMENT="git docker docker-compose python python-pip nodejs npm cmake gcc gdb make"

PACKAGES_ANDROID_AOSP="android-tools android-udev jdk17-openjdk repo"

PACKAGES_AI="python-pytorch python-tensorflow jupyter-notebook python-pip python-scikit-learn python-pandas python-numpy"

PACKAGES_VIRTUALIZATION="qemu virt-manager libvirt ovmf dnsmasq bridge-utils"

PACKAGES_UTILITIES="firefox wget curl htop spectacle ark unzip p7zip kate networkmanager bluez bluez-utils"

# Combine all packages
ALL_PACKAGES="$PACKAGES_BASE $PACKAGES_DESKTOP $PACKAGES_NVIDIA $PACKAGES_GAMING $PACKAGES_DEVELOPMENT $PACKAGES_ANDROID_AOSP $PACKAGES_AI $PACKAGES_VIRTUALIZATION $PACKAGES_UTILITIES"

# === PREPARE NETWORK + MIRRORS ===
echo "🌐 Setting up fresh mirrors..."
pacman -Sy --noconfirm reflector
echo "📡 Finding fastest mirrors..."
reflector --latest 20 \
    --protocol https \
    --sort rate \
    --country 'United States' \
    --fastest 10 \
    --age 12 \
    --save /etc/pacman.d/mirrorlist

# Enable multilib repository
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Syy  # Refresh package databases

# === DISK PARTITIONING ===
echo "💽 Preparing disk for partitioning..."
# Unmount all partitions from /mnt and its submounts (ignore errors)
umount -A --recursive /mnt 2>/dev/null || true
# Try to turn off swap on the target disk (ignore errors)
swapoff "${TARGET_DISK}${PART_SUFFIX}2" 2>/dev/null || true

# Detect BIOS or UEFI and set correct disk label
if [ -d /sys/firmware/efi/efivars ]; then
    echo "UEFI detected: setting disk label to GPT."
    parted -s $TARGET_DISK mklabel gpt || check_success "Partition table creation failed"
    BOOT_MODE="UEFI"
else
    echo "BIOS/Legacy detected: setting disk label to msdos (MBR)."
    parted -s $TARGET_DISK mklabel msdos || check_success "Partition table creation failed"
    BOOT_MODE="BIOS"
fi

# Create EFI partition (550MB) for UEFI, or BIOS boot partition for BIOS
if [ "$BOOT_MODE" = "UEFI" ]; then
    parted -s $TARGET_DISK mkpart primary fat32 1MiB 551MiB || check_success "EFI partition failed"
    parted -s $TARGET_DISK set 1 esp on || check_success "ESP flag failed"
    PART_START=2
else
    parted -s $TARGET_DISK mkpart primary ext4 1MiB 551MiB || check_success "BIOS boot partition failed"
    parted -s $TARGET_DISK set 1 boot on || check_success "Boot flag failed"
    PART_START=2
fi

# Create swap partition
SWAP_END_MIB=$((551 + SWAP_SIZE_MIB))
parted -s $TARGET_DISK mkpart primary linux-swap 551MiB ${SWAP_END_MIB}MiB || check_success "Swap partition failed"

# Create root partition (rest of disk)
parted -s $TARGET_DISK mkpart primary btrfs ${SWAP_END_MIB}MiB 100% || check_success "Root partition failed"

# Format partitions
echo "📝 Formatting partitions..."
mkfs.fat -F32 "${TARGET_DISK}${PART_SUFFIX}1" || check_success "mkfs.fat failed"
mkswap "${TARGET_DISK}${PART_SUFFIX}2" || check_success "mkswap failed"
mkfs.btrfs -f "${TARGET_DISK}${PART_SUFFIX}3" || check_success "mkfs.btrfs failed"

# Mount root partition
mount "${TARGET_DISK}${PART_SUFFIX}3" /mnt || check_success "mount root failed"
cd /mnt

# Create btrfs subvolumes
btrfs subvolume create @ || check_success "subvolume @ failed"
btrfs subvolume create @home || check_success "subvolume @home failed"
btrfs subvolume create @var || check_success "subvolume @var failed"
btrfs subvolume create @opt || check_success "subvolume @opt failed"
btrfs subvolume create @tmp || check_success "subvolume @tmp failed"
cd

# Mount subvolumes
umount /mnt || check_success "umount failed"
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "${TARGET_DISK}${PART_SUFFIX}3" /mnt || check_success "mount @ failed"
mkdir -p /mnt/{boot,home,var,opt,tmp}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "${TARGET_DISK}${PART_SUFFIX}3" /mnt/home || check_success "mount @home failed"
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var "${TARGET_DISK}${PART_SUFFIX}3" /mnt/var || check_success "mount @var failed"
mount -o noatime,compress=zstd,space_cache=v2,subvol=@opt "${TARGET_DISK}${PART_SUFFIX}3" /mnt/opt || check_success "mount @opt failed"
mount -o noatime,compress=zstd,space_cache=v2,subvol=@tmp "${TARGET_DISK}${PART_SUFFIX}3" /mnt/tmp || check_success "mount @tmp failed"

# Mount EFI partition
mount "${TARGET_DISK}${PART_SUFFIX}1" /mnt/boot || check_success "mount EFI failed"

# Enable swap
swapon "${TARGET_DISK}${PART_SUFFIX}2" || check_success "swapon failed"

# Function to retry package installation
install_packages() {
    local packages="$1"
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        echo "📦 Installation attempt $attempt of $max_attempts..."
        if pacstrap /mnt $packages; then
            return 0
        fi
        echo "⚠️ Attempt $attempt failed. Refreshing mirrors..."
        arch-chroot /mnt pacman -Syy
        ((attempt++))
        sleep 10
    done
    return 1
}

# === BASE INSTALLATION ===
echo "📦 Installing base system..."
install_packages "$PACKAGES_BASE" || { echo "Failed to install base packages"; exit 1; }

# Enable multilib in the installed system
if ! grep -q '\[multilib\]' /mnt/etc/pacman.conf; then
    echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /mnt/etc/pacman.conf
fi
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
arch-chroot /mnt pacman -Syy

# Install 32-bit NVIDIA libraries if requested
if [ "$INSTALL_NVIDIA" = true ]; then
    arch-chroot /mnt pacman -S --noconfirm lib32-nvidia-utils
fi

echo "📦 Installing desktop environment..."
install_packages "$PACKAGES_DESKTOP" || { echo "Failed to install desktop packages"; exit 1; }

if [ "$INSTALL_NVIDIA" = true ]; then
    echo "📦 Installing NVIDIA drivers..."
    install_packages "$PACKAGES_NVIDIA" || { echo "Failed to install NVIDIA packages"; exit 1; }
fi

echo "📦 Installing gaming packages..."
install_packages "$PACKAGES_GAMING" || { echo "Failed to install gaming packages"; exit 1; }

echo "📦 Installing development tools..."
install_packages "$PACKAGES_DEVELOPMENT" || { echo "Failed to install development packages"; exit 1; }

echo "📦 Installing Android/AOSP tools..."
install_packages "$PACKAGES_ANDROID_AOSP" || { echo "Failed to install Android tools"; exit 1; }

echo "📦 Installing AI/ML packages..."
install_packages "$PACKAGES_AI" || { echo "Failed to install AI packages"; exit 1; }

echo "📦 Installing virtualization packages..."
install_packages "$PACKAGES_VIRTUALIZATION" || { echo "Failed to install virtualization packages"; exit 1; }

echo "📦 Installing utility packages..."
install_packages "$PACKAGES_UTILITIES" || { echo "Failed to install utility packages"; exit 1; }

# === SYSTEM CONFIGURATION ===
echo "⚙️ Configuring system..."

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# === Timezone & Locale Auto-Detection ===
# Try to auto-detect timezone and locale via geolocation (fallback: Canada/Ontario)
TIMEZONE="America/Toronto"
LOCALE="en_CA.UTF-8"

if command -v curl >/dev/null 2>&1; then
    GEO_INFO=$(curl -s --max-time 5 https://ipapi.co/json/)
    DETECTED_TZ=$(echo "$GEO_INFO" | grep -oP '"timezone":\s*"\K[^"]+')
    DETECTED_LOCALE=$(echo "$GEO_INFO" | grep -oP '"country_code":\s*"\K[^"]+')
    if [ -n "$DETECTED_TZ" ]; then
        TIMEZONE="$DETECTED_TZ"
    fi
    if [ -n "$DETECTED_LOCALE" ]; then
        LOCALE="en_${DETECTED_LOCALE}.UTF-8"
    fi
fi

# Set timezone
echo "🌎 Setting timezone to $TIMEZONE"
arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc

# Set locale
echo "$LOCALE UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LOCALE" > /mnt/etc/locale.conf

# Set hostname
echo $HOSTNAME > /mnt/etc/hostname

# Configure hosts file
cat > /mnt/etc/hosts << EOF
127.0.0.1     localhost
::1           localhost
127.0.1.1     $HOSTNAME.localdomain     $HOSTNAME
EOF

# Set root password
echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd

# Create user
arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,docker -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | arch-chroot /mnt chpasswd

# Configure sudo
echo "%wheel ALL=(ALL) ALL" > /mnt/etc/sudoers.d/wheel

# Configure mkinitcpio
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt btrfs filesystems keyboard fsck)/' /mnt/etc/mkinitcpio.conf
if [ "$INSTALL_NVIDIA" = true ]; then
    sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P
fi

# === VirtualBox Guest Additions ===
# Only install if running in VirtualBox
# Check for dmidecode before using for VirtualBox detection
if command -v dmidecode >/dev/null 2>&1; then
    IS_VBOX=$(grep -q "VirtualBox" /proc/scsi/scsi 2>/dev/null && echo 1 || dmidecode | grep -qi "VirtualBox" && echo 1 || echo 0)
else
    IS_VBOX=$(grep -q "VirtualBox" /proc/scsi/scsi 2>/dev/null && echo 1 || echo 0)
fi
if [ "$IS_VBOX" -eq 1 ]; then
    echo "Detected VirtualBox VM: installing virtualbox-guest-utils."
    arch-chroot /mnt pacman -S --noconfirm virtualbox-guest-utils
fi

# === Bootloader Installation ===
# Detect UEFI or BIOS
if [ -d /sys/firmware/efi/efivars ]; then
    echo "UEFI detected: installing systemd-boot."
    arch-chroot /mnt bootctl install
    cat > /mnt/boot/loader/loader.conf << EOF
default arch.conf
timeout 4
console-mode max
editor no
EOF

    cat > /mnt/boot/loader/entries/arch.conf << EOF
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value "${TARGET_DISK}${PART_SUFFIX}3") rootflags=subvol=@ rw nvidia-drm.modeset=1
EOF
else
    echo "BIOS/Legacy detected: installing GRUB."
    # Check if $TARGET_DISK is a whole disk (not a partition)
    if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
        echo "⚠️  Warning: TARGET_DISK ($TARGET_DISK) looks like a partition, not a disk. Please set it to the disk (e.g., /dev/sda, /dev/vda, /dev/nvme0n1)."
        exit 1
    fi
        arch-chroot /mnt pacman -S --noconfirm grub os-prober
    arch-chroot /mnt grub-install --target=i386-pc --recheck $TARGET_DISK
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    echo "GRUB installation complete."
fi

# Enable services
arch-chroot /mnt systemctl enable sddm NetworkManager docker libvirtd bluetooth

# Configure NVIDIA early loading
if [ "$INSTALL_NVIDIA" = true ]; then
    echo "options nvidia-drm modeset=1" > /mnt/etc/modprobe.d/nvidia.conf
fi

# Enable Docker socket
arch-chroot /mnt systemctl enable docker.socket

# Enable Bluetooth
arch-chroot /mnt systemctl enable bluetooth

# Enable TRIM for SSDs
arch-chroot /mnt systemctl enable fstrim.timer

# Install additional utilities from pacman
arch-chroot /mnt pacman -S --noconfirm fastfetch

echo "✅ Installation complete! You can now reboot."
