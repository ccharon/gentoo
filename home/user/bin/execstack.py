#!/usr/bin/env python3
#
# execstack.py
#
# This script is a replacement for the "execstack" tool.
# It can modify the PT_GNU_STACK program header of an ELF binary,
# making the process stack executable or non-executable.
# Generated with the help of chatgpt.
#
# Gentoo had no easy accessible version of execstack so I made
# this to play Stardew Valley without Error Messages :)
#
# Features:
#   -s   Makes the stack executable (RWX)   [like execstack -s]
#   -c   Makes the stack non-executable (RW) [like execstack -c]
#   -q   Queries the current stack status and prints:
#          "X" if executable,
#          "-" if non-executable,
#          "?" if no PT_GNU_STACK segment exists [like execstack -q]
#
# The script validates:
#   - that the file exists
#   - that it is an ELF binary (checks magic bytes 0x7f 'E' 'L' 'F')
#
# Usage:
#   ./execstack.py -s <elf-file>
#   ./execstack.py -c <elf-file>
#   ./execstack.py -q <elf-file>
#
# Note:
#   If an ELF binary does not contain a PT_GNU_STACK segment, this script
#   cannot add one – that would require relinking the binary.
#

import sys
import os
import struct

# === Constants from ELF specification ===
PF_X = 0x1  # Flag: segment is executable
PF_W = 0x2  # Flag: segment is writable
PF_R = 0x4  # Flag: segment is readable
PT_GNU_STACK = 0x6474e551  # Program header type: GNU stack segment


def validate_elf_file(filename):
    """Check that the file exists and is an ELF binary."""
    if not os.path.isfile(filename):
        print(f"Error: {filename} is not a file")
        sys.exit(1)

    with open(filename, "rb") as f:
        magic = f.read(4)
    if magic != b"\x7fELF":
        print(f"Error: {filename} is not an ELF binary")
        sys.exit(1)


def parse_program_headers(elf_data: bytes):
    """
    Parse the program headers of an ELF file and return a list of (offset, entry, format).
    Each entry is a list of fields (struct unpacked).
    """
    e_ident = elf_data[:16]
    is_64bit = (e_ident[4] == 2)         # EI_CLASS: 1 = 32-bit, 2 = 64-bit
    is_little_endian = (e_ident[5] == 1) # EI_DATA: 1 = little, 2 = big endian
    endian_prefix = '<' if is_little_endian else '>'

    if is_64bit:
        ph_format = endian_prefix + 'IIQQQQQQ'  # Elf64_Phdr
        e_phoff_offset = 32
        e_phentsize_offset = 54
        e_phnum_offset = 56
        word_size = 'Q'
    else:
        ph_format = endian_prefix + 'IIIIIIII'  # Elf32_Phdr
        e_phoff_offset = 28
        e_phentsize_offset = 42
        e_phnum_offset = 44
        word_size = 'I'

    e_phoff = struct.unpack_from(endian_prefix + word_size, elf_data, e_phoff_offset)[0]
    e_phentsize = struct.unpack_from(endian_prefix + 'H', elf_data, e_phentsize_offset)[0]
    e_phnum = struct.unpack_from(endian_prefix + 'H', elf_data, e_phnum_offset)[0]

    headers = []
    for i in range(e_phnum):
        ph_offset = e_phoff + i * e_phentsize
        ph_entry = list(struct.unpack_from(ph_format, elf_data, ph_offset))
        headers.append((ph_offset, ph_entry, ph_format))
    return headers


def read_stack_flags(filename):
    """Return p_flags of PT_GNU_STACK, or None if not found."""
    with open(filename, 'rb') as f:
        elf_data = f.read()

    for _, ph_entry, _ in parse_program_headers(elf_data):
        if ph_entry[0] == PT_GNU_STACK:
            return ph_entry[1]
    return None


def set_stack_flags(filename, make_executable: bool):
    """Modify PT_GNU_STACK flags in-place."""
    with open(filename, 'rb') as f:
        elf_data = bytearray(f.read())

    for ph_offset, ph_entry, ph_format in parse_program_headers(elf_data):
        if ph_entry[0] == PT_GNU_STACK:
            old_flags = ph_entry[1]
            new_flags = (PF_R | PF_W | PF_X) if make_executable else (PF_R | PF_W)
            ph_entry[1] = new_flags
            struct.pack_into(ph_format, elf_data, ph_offset, *ph_entry)
            print(f"PT_GNU_STACK flags changed {old_flags:#x} -> {new_flags:#x}")
            break
    else:
        print("PT_GNU_STACK not found – cannot patch (relinking required).")
        return

    with open(filename, 'wb') as f:
        f.write(elf_data)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('-s', '-c', '-q'):
        print(f"Usage: {sys.argv[0]} <-s|-c|-q> <elf-file>")
        print("  -s   Make stack executable (like execstack -s)")
        print("  -c   Make stack non-executable (like execstack -c)")
        print("  -q   Query current stack permission (like execstack -q)")
        sys.exit(1)

    mode_flag, filename = sys.argv[1], sys.argv[2]
    validate_elf_file(filename)

    if mode_flag == '-s':
        set_stack_flags(filename, make_executable=True)
    elif mode_flag == '-c':
        set_stack_flags(filename, make_executable=False)
    elif mode_flag == '-q':
        flags = read_stack_flags(filename)
        if flags is None:
            print(f"? {filename}")
        else:
            marker = "X" if (flags & PF_X) else "-"
            print(f"{marker} {filename}")
