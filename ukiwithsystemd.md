# Boot Unified Kernel Images with systemd-boot

## Install required stuff
- reinstall systemd with gnuefi useflag
- run bootctl install to install systemd-boot
- emerge installkernel-systemd-boot to replace installkernel-gentoo
- modify dracut conf to look like this
```bash
# PUT YOUR CONFIG IN separate files
# in /etc/dracut.conf.d named "<name>.conf"
# SEE man dracut.conf(5) for options
hostonly="yes"
hostonly_cmdline=yes

use_fstab=yes
compress=xz
show_modules=yes

# create an unified kernel image
uefi=yes

# integrate microcode updates
early_microcode=yes

# point to the correct UEFI stub loader
uefi_stub=/usr/lib/systemd/boot/efi/linuxx64.efi.stub

# set files used to secure boot sign
uefi_secureboot_cert=/etc/efi-keys/DB.crt
uefi_secureboot_key=/etc/efi-keys/DB.key

# kernel command-line parameters
kernel_cmdline="root=zfs:AUTO loglevel=3 quiet splash"
```
