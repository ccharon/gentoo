#!/bin/env bash

# This script creates a signed unified linux.efi kernel image.
#
# direct efi boot is configured by:
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0000 -L "Gentoo" -l '\EFI\gentoo\linux.efi'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0001 -L "Gentoo Previous Kernel" -l '\EFI\gentoo\linux.old'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0002 -L "EFI Shell" -l '\EFI\gentoo\shell.efi'
# efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0003 -L "KeyTool" -l '\EFI\gentoo\keytool.efi'
# (edk2-ovmf ebuild) copy /usr/share/edk2-ovmf/Shell.efi to /boot/efi/EFI/gentoo/shell.efi
# (efitools ebuild) copy /usr/share/efitools/efi/KeyTool.efi to /boot/efi/EFI/gentoo/keytool.efi

# the directory where kernel + initrd are stored by gentoo-kernel ebuild
BOOT_DIR="/boot"

# the place the esp partition is mounted
EFI_MOUNTPOINT="${BOOT_DIR}/efi"

# location to store linux.efi
EFI_DIR_GENTOO="${EFI_MOUNTPOINT}/EFI/gentoo"

# efi stub for direct kernel boot (emerge systemd with USE="gnuefi")
EFI_STUB="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"

# properties like rootfs= or qiet splash are expected in this file
KERNEL_CMDLINE="/etc/kernel/cmdline"

# directory where certificates like pk, kek and db are stored
SECURE_BOOT_CERT_DIR="/etc/efi-keys"


usage() {
  command=${0##*/}
  echo "Usage: ${command} -k imgdir [-l disklabel] [-o imgdir.img]";
  echo " -k, --kver        kernel version"
  echo " -h  --help        shows this help"
  echo
  echo "This script creates a (signed) unified linux.efi"
  echo
  echo "Examples:"
  echo "${command} --kver 5.17.5-gentoo-dist"
  echo "${command} without parameters displays this help"
  echo
}

# No parameters, just show usage
if [ ${#} -lt 1 ]; then usage ; exit 0; fi

# parse command line parameters
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

# (re)create initramfs (zfs module gets build after kernel install so the initramfs is missing zfs.ko)
echo "Executing \"dracut -f --kver ${kver}\""
if ! $(dracut -f --kver "${kver}" > /dev/null 2>&1) ; then
    echo "Error executing dracut, try manually executing \"dracut -f --kver ${kver}\" to see whats wrong."
    exit 1
fi

# kernel + initrd source
kernel_src="${BOOT_DIR}/vmlinuz-${kver}"
initrd_src="${BOOT_DIR}/initramfs-${kver}.img"

# unified image destination
linux_dst="${EFI_DIR_GENTOO}/linux.efi"

# sanity checks
if ! $(mountpoint -q "${EFI_MOUNTPOINT}"); then echo "${EFI_MOUNTPOINT} has to be mounted!" ; exit 1 ; fi
if ! [ -f "${KERNEL_CMDLINE}" ] ; then echo "File ${KERNEL_CMDLINE} does not exist." ; exit 1 ; fi
if ! [ -f "${EFI_STUB}" ] ; then echo "File ${EFI_STUB} does not exist, emerge systemd with USE=\"gnuefi\"" ; exit 1 ; fi
if ! [ -d "${EFI_DIR_GENTOO}" ]; then echo "Directory ${EFI_DIR_GENTOO} does not exist." ; exit 1 ; fi
if ! [ -f "${kernel_src}" ] ; then echo "File ${kernel_src} does not exist." ; exit 1 ; fi
if ! [ -f "${initrd_src}" ] ; then echo "File ${initrd_src} does not exist." ; exit 1 ; fi

# if a version already exists copy to .old
if [ -f "${linux_dst}" ] ; then
    echo "${linux_dst} found, creating linux.old"
    cp "${linux_dst}" "${EFI_DIR_GENTOO}/linux.old"
fi

# create new unified image
echo "Creating ${linux_dst}"
objcopy \
    --add-section .osrel="/usr/lib/os-release" --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="${KERNEL_CMDLINE}" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="${kernel_src}" --change-section-vma .linux=0x2000000 \
    --add-section .initrd="${initrd_src}" --change-section-vma .initrd=0x3000000 \
    "${EFI_STUB}" "${linux_dst}"

# Signing the kernel if a certificate exists
if ! [ -f "${SECURE_BOOT_CERT_DIR}/DB.key" ] ; then exit 0 ; fi
if ! [ -f "${SECURE_BOOT_CERT_DIR}/DB.crt" ] ; then exit 0 ; fi

echo "Signing ${linux_dst} with ${SECURE_BOOT_CERT_DIR}/DB.key"
sbsign --key "${SECURE_BOOT_CERT_DIR}/DB.key" \
    --cert "${SECURE_BOOT_CERT_DIR}/DB.crt" \
    --output "${linux_dst}" \
    "${linux_dst}"
