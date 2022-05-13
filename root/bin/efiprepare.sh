#!/bin/env bash

# This script recreates the initramfs and then copies kernel and initramfs to a location for direct efi boot.
# direct efi boot is configured by:

# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0000 -L "Gentoo" -l '\EFI\gentoo\kernel.efi' --unicode 'initrd=\EFI\gentoo\initrd.img dozfs root=ZFS=rpool/ROOT/coyote quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0002 -L "Gentoo Debug" -l '\EFI\gentoo\kernel.efi' --unicode 'initrd=\EFI\gentoo\initrd.img dozfs root=ZFS=rpool/ROOT/coyote'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0004 -L "Gentoo Previous Kernel" -l '\EFI\gentoo\kernel.old' --unicode 'initrd=\EFI\gentoo\initrd.old dozfs root=ZFS=rpool/ROOT/coyote'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0003 -L "EFI Shell" -l '\EFI\gentoo\shell.efi'

# /usr/share/edk2-ovmf/Shell.efi aus edk2-ovmf ebuild nach /boot/efi/EFI/gentoo/shell.efi kopieren


EFI_MOUNTPOINT="/boot/efi"
BOOT_DIR="/boot"
EFI_LOADER_DIR="/boot/efi/EFI/gentoo"

usage() {
  command=${0##*/}
  echo "Usage: ${command} -k imgdir [-l disklabel] [-o imgdir.img]";
  echo " -k, --kver        kernel version"
  echo " -h  --help        shows this help"
  echo
  echo "Examples:"
  echo "${command} --kver 5.17.5-gentoo-dist"
  echo "${command} without parameters displays this help"
  echo
}

# No parameters, just show usage
if [ ${#} -lt 1 ]; then usage ; exit 0; fi

opts=$(getopt --options k:h --long kver:,help  --name "$0" -- "$@")
if [ ${?} -ne 0 ] ; then usage ; exit 1 ; fi

eval set -- "${opts}"

kver=""

while true ; do
  case "${1}" in
    -k | --kver ) kver="${2}"; shift 2;;
    -h | --help ) usage ; exit 0 ;;
    -- ) shift ; break;;
    *) usage ; exit 1;;
  esac
done

# recreate initramfs (zfs module gets build after kernel install so the initramfs is missing zfs.ko)
dracut -f --kver "${kver}"

# kernel + initrd copy source
kernel_src="${BOOT_DIR}/vmlinuz-${kver}"
initrd_src="${BOOT_DIR}/initramfs-${kver}.img"

# Check if given kernel + initrd Version exist
if ! [ -f "${kernel_src}" ] ; then echo "File ${kernel_src} does not exist." ; exit 1 ; fi
if ! [ -f "${initrd_src}" ] ; then echo "File ${initrd_src} does not exist." ; exit 1 ; fi

# Check if EFI Partition is mounted
if ! $(mountpoint -q "${EFI_MOUNTPOINT}"); then
    echo "${EFI_MOUNTPOINT} has to be mounted!"
    exit 1
fi

# Check if EFI Loader Directory exists
if ! [ -d "${EFI_LOADER_DIR}" ]; then echo "Directory ${EFI_LOADER_DIR} does not exist." ; exit 1 ; fi

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
