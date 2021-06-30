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

clear
timedatectl set-ntp true

#cecho "Updating mirrorlist..."
#pacman -Sy pacman-contrib
#cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
#curl -s "https://www.archlinux.org/mirrorlist/?country=ES&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist
#todo meter en tmp

cecho "Deleting old partition scheme on $DISK"
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

cecho "Creating new partition scheme on $DISK."
sgdisk --clear \
    --new=1:0:+512MiB --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:0 --typecode=2:8300 --change-name=2:ROOT \
    $DISK
partprobe "$DISK"

cecho "Encrypting system partition"
cryptsetup -q luksFormat --perf-no_read_workqueue --perf-no_write_workqueue --type luks2 --cipher aes-xts-plain64 --key-size 512 --iter-time 2000 --pbkdf argon2id --hash sha3-512 ${DISK}2
cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open ${DISK}2 ROOT

cecho "Formatting the partitions"
BTRFS="/dev/mapper/ROOT"
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
mkdir -p /mnt/boot
mount $EFI /mnt/boot/

cecho "Installing the base system"
pacstrap /mnt base base-devel linux intel-ucode linux-headers linux-firmware iwd btrfs-progs vim \
    openssh 
    tmux htop arch-wiki-docs snapper sudo reflector git pkgfile \
    zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting

cecho "Generating fstab..."
genfstab -L /mnt > /mnt/etc/fstab

cecho "Setting common..."
echo "$HOSTNAME" > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8"  > /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
cp -p /mnt/usr/share/zoneinfo/Europe/Madrid /mnt/etc/localtime
#cp -p /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

cecho "Configuring /etc/mkinitcpio.conf."
mv /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.orig
cat > /mnt/etc/mkinitcpio.conf  <<EOF
MODULES=(btrfs)
BINARIES=(/usr/bin/btrfs)
FILES=()
HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)
EOF

cecho "Chroot into the system"
arch-chroot /mnt /bin/bash <<EOF
    echo "Setting up the hardware clock..."
    hwclock --systohc

    echo "Setting locale..."
    locale-gen
    
    echo "Making full system upgrade..."
    pacman --noconfirm -Syu

    echo "Generating initramfs"
    mkinitcpio -P
    
    echo "Installing systemd-boot bootloader..."
    bootctl install

    echo "Configuring snapper..."
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots 
    mkdir /.snapshots
    mount -a
    chmod 750 /.snapshots
    
    echo "Setting users..."
    echo "root:${PASS}" | chpasswd
    groupadd -r autologin
    useradd -m -g users -G wheel,autologin -s /bin/zsh $USER
    echo "${USER}:${PASS}" | chpasswd
    echo $USER ALL=\(ALL\) NOPASSWD: ALL >> /etc/sudoers
EOF

cecho "Setting up loader conf..."
cat > /mnt/boot/loader/loader.conf <<EOF
default null
timeout 4
editor no
EOF

cecho "Setting up loader entry..."
cat > /mnt/boot/loader/entries/null.conf <<EOF
title          NULL
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options cryptdevice=PARTLABEL=ROOT:ROOT root=/dev/mapper/ROOT rootflags=subvol=@ rw intel_pstate=no_hwp rd.luks.options=discard mem_sleep_default=deep
EOF

cecho "Enabling services...."
#systemctl enable apparmor --root=/mnt #todo
systemctl enable iwd --root=/mnt
systemctl enable snapper-timeline.timer --root=/mnt 
systemctl enable snapper-cleanup.timer --root=/mnt 

cecho "Misc...."
cp -Rp  /var/lib/iwd /mnt/var/lib/
sync
umount /mnt/boot
umount -R /mnt
cryptsetup close ROOT
reboot




