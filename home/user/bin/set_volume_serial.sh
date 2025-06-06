#!/bin/bash

# -----------------------------------------------------------------------------
# Script: set_volume_serial.sh
#
# Description:
#   This script generates a random Volume Serial Number and writes it into the
#   boot sector of a raw MS-DOS formatted disk image (such as a 1.44MB floppy image).
#
#   The Volume Serial Number is a 4-byte value located at offset 0x27 (decimal 39)
#   in the boot sector of FAT12/16 file systems. It is stored in little-endian format
#   and used by DOS, Windows, and other systems to uniquely identify volumes.
#
# Functionality:
#   - Generates 4 random bytes from /dev/urandom
#   - Prints the serial number in human-readable "XXXX-XXXX" format
#   - Writes the 4 bytes into the image at offset 0x27 using dd
#
# Usage:
#   ./set_volume_serial.sh <disk_image>
#
#   <disk_image> should be a raw floppy disk image file.
#
# Example:
#   ./set_volume_serial.sh msdos.img
#   Generated Volume Serial Number: A7F2-19B3
#   Serial number written to msdos.img
#
# Notes:
#   - This script overwrites only the 4-byte serial field and does not affect
#     any other part of the disk image.
#   - The displayed serial number is converted from little-endian to match
#     how operating systems typically display it.
# -----------------------------------------------------------------------------

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <disk_image>"
    exit 1
fi

image="$1"

if [[ ! -f "$image" ]]; then
    echo "Error: File '$image' not found."
    exit 1
fi

# Generate 4 random bytes (32 bits)
# Using /dev/urandom and hexdump for portability
random_bytes=$(head -c 4 /dev/urandom | xxd -p)

# Extract bytes
b0=${random_bytes:0:2}
b1=${random_bytes:2:2}
b2=${random_bytes:4:2}
b3=${random_bytes:6:2}

# The serial is stored little-endian per 16-bit word:
# So actual stored order is b0 b1 b2 b3 (already in random_bytes)
# For display, swap each word bytes:

low_word="${b1}${b0}"
high_word="${b3}${b2}"

echo "Generated Volume Serial Number: ${high_word^^}-${low_word^^}"

# Write the 4 bytes back to the image at offset 0x27 (decimal 39)
# Use printf to create a binary file with those bytes
printf "\\x$b0\\x$b1\\x$b2\\x$b3" | dd of="$image" bs=1 seek=39 count=4 conv=notrunc status=none

echo "Serial number written to $image"
