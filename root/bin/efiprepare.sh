#!/bin/env bash

# This script recreates the initramfs and then copies kernel and initramfs to a location for direct efi boot.
# direct efi boot is configured by:

# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0000 -L "Gentoo" -l '\EFI\gentoo\linux.efi'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0004 -L "Gentoo Previous Kernel" -l '\EFI\gentoo\linux.old'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0003 -L "EFI Shell" -l '\EFI\gentoo\shell.efi'

# /usr/share/edk2-ovmf/Shell.efi aus edk2-ovmf ebuild nach /boot/efi/EFI/gentoo/shell.efi kopieren


BOOT_DIR="/boot"

EFI_MOUNTPOINT="/boot/efi"
EFI_LOADER_DIR="/boot/efi/EFI/gentoo"
EFI_STUB="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"

KERNEL_CMDLINE="/etc/kernel/cmdline"


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

# kernel command parameters to append to image
if ! [ -f "${KERNEL_CMDLINE}" ] ; then echo "File ${KERNEL_CMDLINE} does not exist." ; exit 1 ; fi

# kernel command parameters to append to image
if ! [ -f "${EFI_STUB}" ] ; then echo "File ${EFI_STUB} does not exist, emerge systemd with USE=\"gnuefi\"" ; exit 1 ; fi

# recreate initramfs (zfs module gets build after kernel install so the initramfs is missing zfs.ko)
echo "Executing \"dracut -f --kver ${kver}\""
if ! $(dracut -f --kver "${kver}" > /dev/null 2>&1) ; then
    echo "Error executing dracut, try manually executing \"dracut -f --kver ${kver}\" to see whats wrong."
    exit 1
fi

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

# copy destination
linux_dst="${EFI_LOADER_DIR}/linux.efi"

# If a version already exists copy to .old
if [ -f "${linux_dst}" ] ; then
    echo "${linux_dst} found, creating linux.old"
    cp -v "${linux_dst}" "${EFI_LOADER_DIR}/linux.old"
fi

# Create new Kernel image

echo "Creating linux.efi ..."
objcopy \
    --add-section .osrel="/usr/lib/os-release" --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="${KERNEL_CMDLINE}" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="${kernel_src}" --change-section-vma .linux=0x2000000 \
    --add-section .initrd="${initrd_src}" --change-section-vma .initrd=0x3000000 \
    "${EFI_STUB}" "${linux_dst}"
    
# Signing the kernel if a certificate exists
if ! [ -f /etc/efi-keys/DB.key ] ; then exit 0 ; fi
if ! [ -f /etc/efi-keys/DB.crt ] ; then exit 0 ; fi

echo "Signing kernel with /etc/efi-keys/DB.key"
sbsign --key /etc/efi-keys/DB.key --cert /etc/efi-keys/DB.crt --output  "${EFI_LOADER_DIR}/linux-signed.efi" "${linux_dst}"
mv "${EFI_LOADER_DIR}/linux-signed.efi" "${linux_dst}"
