#!/bin/bash
# -----------------------------------------------------------------------------
# Script: get_volume_serial.sh
#
# Description:
#   This script reads the Volume Serial Number from a raw MS-DOS formatted
#   disk image (such as a 1.44MB floppy image).
#
#   The Volume Serial Number is a 4-byte value located at offset 0x27 (decimal 39)
#   in the boot sector. It is stored in little-endian format and is typically used
#   to uniquely identify FAT-formatted volumes.
#
# Output:
#   Displays the volume serial number in the standard "XXXX-XXXX" format.
#
# Usage:
#   ./get_volume_serial.sh <disk_image>
#
#   <disk_image> should be a raw floppy disk image file.
#
# Example:
#   ./get_volume_serial.sh msdos.img
#   Volume Serial Number: 3A1E-11F2
#
# Notes:
#   - The script verifies that the input file exists.
#   - The serial number is interpreted correctly with regard to FAT's little-endian
#     storage convention.
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

# Read 4 bytes from offset 0x27
serial_bytes=$(dd if="$image" bs=1 skip=39 count=4 2>/dev/null | xxd -p)

# serial_bytes is 8 hex chars, 4 bytes: b0 b1 b2 b3
b0=${serial_bytes:0:2}
b1=${serial_bytes:2:2}
b2=${serial_bytes:4:2}
b3=${serial_bytes:6:2}

# Swap bytes in each word (little endian)
low_word="${b1}${b0}"
high_word="${b3}${b2}"

# Print as uppercase XXXX-XXXX
echo "Volume Serial Number: ${high_word^^}-${low_word^^}"
