#!/usr/bin/env -S bash -e

# Update the system clock
timedatectl set-ntp true

# Cleaning the TTY.
clear

# Selecting the kernel flavor to install. 
kernel_selector () {
    echo "List of kernels:"
    echo "1) Stable — Vanilla Linux kernel and modules, with a few patches applied."
    echo "2) Hardened — A security-focused Linux kernel."
    echo "3) Longterm — Long-term support (LTS) Linux kernel and modules."
    echo "4) Zen Kernel — Optimized for desktop usage."
    read -r -p "Insert the number of the corresponding kernel: " choice
    echo "$choice will be installed"
    case $choice in
        1 ) kernel=linux
            ;;
        2 ) kernel=linux-hardened
            ;;
        3 ) kernel=linux-lts
            ;;
        4 ) kernel=linux-zen
            ;;
        * ) echo "You did not enter a valid selection."
            kernel_selector
    esac
}

# Checking the microcode to install.
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ $CPU == *"AuthenticAMD"* ]]
then
    microcode=amd-ucode
else
    microcode=intel-ucode
fi

# Selecting the target for the installation.
PS3="Select the disk where Arch Linux is going to be installed: "
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
    DISK=$ENTRY
    echo "Installing Arch Linux on $DISK."
    break
done

# Deleting old partition scheme.
read -r -p "This will delete the current partition table on $DISK. Do you agree [y/N]? " response
response=${response,,}
if [[ "$response" =~ ^(yes|y)$ ]]
then
    wipefs -af "$DISK" 
    echo YES | sgdisk --zap-all "$DISK"
    cryptsetup close crypt
    cryptsetup erase "$DISK" 
    cryptsetup open --type plain -d /dev/urandom "$DISK" wipe
    dd if=/dev/zero of=/dev/mapper/wipe status=progress bs=1M count=2000
    sync
    cryptsetup close wipe
    sleep 1
    cryptsetup erase "$DISK" 
else
    echo "Quitting."
    exit
fi

# Creating a new partition scheme.
echo "Creating new partition scheme on $DISK."
sgdisk --clear \
    --new=1:0:+512MiB --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:0 --typecode=2:8300 --change-name=2:ROOT \
    $DISK

# Informing the Kernel of the changes.
echo "Informing the Kernel about the disk changes."
partprobe "$DISK"


# Encrypt system partition
echo "Encrypting system partition"
cryptsetup luksFormat --perf-no_read_workqueue --perf-no_write_workqueue --type luks2 --cipher aes-xts-plain64 --key-size 512 --iter-time 2000 --pbkdf argon2id --hash sha3-512 ${DISK}2
cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open ${DISK}2 crypt

# Formatting the partitions
echo "Formatting the partitions"
BTRFS="/dev/mapper/crypt"
EFI="${DISK}1"
mkfs.vfat -F32 -n "EFI"  $EFI
mkfs.btrfs -L ROOT $BTRFS

# Creating BTRFS subvolumes.
echo "Creating BTRFS subvolumes."
mount $BTRFS /mnt
btrfs su cr /mnt/@ &>/dev/null
btrfs su cr /mnt/@home &>/dev/null
btrfs su cr /mnt/@snapshots &>/dev/null
btrfs su cr /mnt/@var_log &>/dev/null

# Mounting the newly created subvolumes.
umount /mnt
echo "Mounting the newly created subvolumes."
btrfs_o=x-mount.mkdir,ssd,noatime,space_cache,compress=zstd
mount -o $btrfs_o,subvol=@ $BTRFS /mnt
mount -o $btrfs_o,autodefrag,discard=async,subvol=@home $BTRFS /mnt/home
mount -o $btrfs_o,autodefrag,discard=async,subvol=@snapshots $BTRFS /mnt/.snapshots
mount -o $btrfs_o,autodefrag,discard=async,nodatacow,subvol=@var_log $BTRFS /mnt/var/log
chattr +C /mnt/var/log
mkdir /mnt/boot
mount $EFI /mnt/boot/
exit

# Pacstrap (setting up a base sytem onto the new root).
echo "Installing the base system (it may take a while)."
pacstrap /mnt base base-devel linux $microcode linux-headers linux-firmware iwd btrfs-progs vim \
    tmux htop arch-wiki-docs snapper sudo apparmor reflector


#cryptsetup close crypt



