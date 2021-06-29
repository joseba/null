#!/usr/bin/env -S bash -e

DISK=/dev/sda
HOSTNAME=null
USER=jsb
PASS=$1

RED='\033[0;31m'
NC='\033[0m' 

cecho() {
  echo -e "$RED $@ $NC"
}

#cecho "Updating mirrorlist..."
#curl -s "https://www.archlinux.org/mirrorlist/?country=ES&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

# Update the system clock
timedatectl set-ntp true

# Cleaning the TTY.
clear

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
wipefs -af "$DISK" 
echo YES | sgdisk --zap-all "$DISK"
cryptsetup close crypt
cryptsetup erase "$DISK" 
cryptsetup open --type plain -d /dev/urandom "$DISK" wipe
dd if=/dev/zero of=/dev/mapper/wipe status=progress bs=1M count=2000
sync
cryptsetup close wipe
sync
cryptsetup erase "$DISK" 

# Creating a new partition scheme.
echo "Creating new partition scheme on $DISK."
sgdisk --clear \
    --new=1:0:+512MiB --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:0 --typecode=2:8300 --change-name=2:ROOT \
    $DISK

# Informing the Kernel of the changes.
echo "Informing the Kernel about the disk changes."
partprobe "$DISK"

cecho "Encrypting system partition"
echo $PASS | cryptsetup -q luksFormat --perf-no_read_workqueue --perf-no_write_workqueue --type luks2 --cipher aes-xts-plain64 --key-size 512 --iter-time 2000 --pbkdf argon2id --hash sha3-512 ${DISK}2 -
echo $PASS | cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open ${DISK}2 crypt -

cecho "Formatting the partitions"
BTRFS="/dev/mapper/crypt"
EFI="${DISK}1"
mkfs.vfat -F32 -n "EFI"  $EFI
mkfs.btrfs --force -L ROOT $BTRFS

cecho "Creating BTRFS subvolumes."
mount $BTRFS /mnt
btrfs su cr /mnt/@ &>/dev/null
btrfs su cr /mnt/@home &>/dev/null
btrfs su cr /mnt/@snapshots &>/dev/null
btrfs su cr /mnt/@var_log &>/dev/null

cecho "Mounting the newly created subvolumes."
umount /mnt
btrfs_o=x-mount.mkdir,ssd,noatime,space_cache,compress=zstd
mount -o $btrfs_o,subvol=@ $BTRFS /mnt
mount -o $btrfs_o,autodefrag,discard=async,subvol=@home $BTRFS /mnt/home
mount -o $btrfs_o,autodefrag,discard=async,subvol=@snapshots $BTRFS /mnt/.snapshots
mount -o $btrfs_o,autodefrag,discard=async,nodatacow,subvol=@var_log $BTRFS /mnt/var/log
chattr +C /mnt/var/log
mkdir /mnt/boot
mount $EFI /mnt/boot/

cecho "Installing the base system"
pacstrap /mnt base base-devel linux $microcode linux-headers linux-firmware iwd btrfs-progs vim \
    tmux htop arch-wiki-docs snapper sudo apparmor reflector git pkgfile 

echo "Generating fstab..."
genfstab -L /mnt > /mnt/etc/fstab

echo "Setting hostname..."
echo "$HOSTNAME" > /mnt/etc/hostname

echo "Setting up locales..."
echo "en_US.UTF-8 UTF-8"  > /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf

# Setting hosts file.
echo "Setting hosts file."
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

echo "Setting time zone..."
cp -p /mnt/usr/share/zoneinfo/Europe/Madrid /mnt/etc/localtime

# Configuring /etc/mkinitcpio.conf.
mv /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.orig
cat > /mnt/etc/mkinitcpio.conf  <<EOF
MODULES=(btrfs)
BINARIES=(/usr/bin/btrfs)
FILES=()
HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)
EOF


# Chroot into the system
arch-chroot /mnt /bin/bash <<EOF

    echo "Setting time zone..."
    ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime

    echo "Setting up the hardware clock..."
    hwclock --systohc

    echo "Setting locale..."
    locale-gen

    echo "Setting hostname..."
    echo $HOSTNAME > /etc/hostname

    echo "Setting up hosts file..."
    cat << CONF > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME
CONF




    echo "Generating initramfs"
    mkinitcpio -P

    echo "Configuring snapper..."
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots &>/dev/null
    mkdir /.snapshots
   mount -a
    chmod 750 /.snapshots
    
    echo "Setting users..."
    echo "root:${PASS}" | chpasswd
    useradd -m -g users -s /bin/bash jsb
    echo "jsb:${PASS}" | chpasswd
    echo jsb ALL=\(ALL\) NOPASSWD: ALL >> /etc/sudoers

    echo "Installing systemd-boot bootloader..."
    bootctl install

Tue Jun 29 05:50:24 PM UTC 2021
[root@archiso entries]# cat 2021-06-29_17-39-26.conf
# Created by: archinstall
# Created on: 2021-06-29_17-39-26
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options cryptdevice=PARTUUID=a3fc8619-1298-4d4a-ac5b-afcf97e07c87:luksdev root=/dev/mapper/luksdev rw intel_pstate=no_hwp
[root@archiso entries]# blkid
/dev/sda1: LABEL_FATBOOT="EFI" LABEL="EFI" UUID="DFC9-6CBC" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="EFI" PARTUUID="d4530ff6-7514-4ae4-a13e-94ff09cd7d6a"
/dev/sda2: UUID="ea2f078d-a006-4db6-8873-fec918c8b7c9" TYPE="crypto_LUKS" PARTLABEL="primary" PARTUUID="a3fc8619-1298-4d4a-ac5b-afcf97e07c87"
/dev/mapper/luksloop: UUID="3e1e0739-f1c8-4a3a-bf52-96918d3fbe9b" UUID_SUB="5e1a3bb7-9033-44ff-8219-42ada0db17f3" BLOCK_SIZE="4096" TYPE="btrfs"
/dev/sdb1: LABEL="ARCH_202106" UUID="1BFA-1052" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="3a616acb-01"
/dev/loop0: TYPE="squashfs"
[root@archiso entries]# cat /boot/loader/
entries/     loader.conf  random-seed
[root@archiso entries]# cat /boot/loader/loader.conf
default 2021-06-29_17-39-26
timeout 4
editor no


    echo "Setting up loader configuration..."
    cat << CONF > /boot/loader/loader.conf
default arch
timeout 4
editor no
CONF

    echo "Setting up bootloader entry..."
    cat << CONF > /boot/loader/entries/arch.conf
title          NULL
linux             /vmlinuz-linux
initrd            /initramfs-linux.img
options        root=LABEL=ROOT rw rootfstype=btrfs rootflags=subvol=@
CONF

    echo "Making full system upgrade..."
    pacman --noconfirm -Syu

EOF

echo "Enabling services...."
systemctl enable apparmor --root=/mnt
systemctl enable iwd --root=/mnt
systemctl enable snapper-timeline.timer --root=/mnt 
systemctl enable snapper-cleanup.timer --root=/mnt 

echo "Misc...."
cp -Rp  /var/lib/iwd /mnt/var/lib/





