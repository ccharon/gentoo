#!/bin/env bash

# This script copies kernel and initramfs to a location for direct efi boot.
# it gets called with 2 parameters
# ${1} is the kernel version i.e. : 5.17.6-gentoo-dist
# ${2} is the path to to new kernel itself /boot/vmlinuz-5.17.6-gentoo-dist

# direct efi boot is configured by:
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0000 -L "Gentoo" -l '\EFI\gentoo\kernel.efi' --unicode 'initrd=\EFI\gentoo\initrd.img dozfs root=ZFS=rpool/ROOT/coyote quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0002 -L "Gentoo Debug" -l '\EFI\gentoo\kernel.efi' --unicode 'initrd=\EFI\gentoo\initrd.img dozfs root=ZFS=rpool/ROOT/coyote'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0004 -L "Gentoo Previous Kernel" -l '\EFI\gentoo\kernel.old' --unicode 'initrd=\EFI\gentoo\initrd.old dozfs root=ZFS=rpool/ROOT/coyote'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0003 -L "EFI Shell" -l '\EFI\gentoo\shell.efi'

# /usr/share/edk2-ovmf/Shell.efi aus edk2-ovmf ebuild nach /boot/efi/EFI/gentoo/shell.efi kopieren

EFI_MOUNTPOINT="/boot/efi"
BOOT_DIR="/boot"
EFI_LOADER_DIR="/boot/efi/EFI/gentoo"

kver="${1}"
kernel_src="${2}"
initrd_src="${BOOT_DIR}/initramfs-${kver}.img"

# Check if given kernel + initrd Version exist
if ! [ -f "${kernel_src}" ] ; then echo "File ${kernel_src} does not exist." ; exit 1 ; fi
if ! [ -f "${initrd_src}" ] ; then echo "File ${initrd_src} does not exist." ; exit 1 ; fi

# Check if EFI Partition is mounted
if ! $(mountpoint -q "${EFI_MOUNTPOINT}") ; then echo "${EFI_MOUNTPOINT} has to be mounted!" ; exit 1 ; fi

# Check if EFI Loader Directory exists
if ! [ -d "${EFI_LOADER_DIR}" ] ; then echo "Directory ${EFI_LOADER_DIR} does not exist." ; exit 1 ; fi

# kernel + initrd copy destination
kernel_dst="${EFI_LOADER_DIR}/kernel.efi"
initrd_dst="${EFI_LOADER_DIR}/initrd.img"

# If a version already exists copy to .old
if [ -f "${kernel_dst}" ] ; then
    echo "${kernel_dst} found, creating kernel.old"
    cp -v "${kernel_dst}" "${EFI_LOADER_DIR}/kernel.old"
fi

if [ -f "${initrd_dst}" ] ; then
    echo "${initrd_dst} found, creating initrd.old"
    cp -v "${initrd_dst}" "${EFI_LOADER_DIR}/initrd.old"
fi

# Copy new kernel + initrd to destination
echo "Copy new kernel + initrd to ${EFI_LOADER_DIR}"
cp -v "${kernel_src}" "${kernel_dst}"
cp -v "${initrd_src}" "${initrd_dst}"
