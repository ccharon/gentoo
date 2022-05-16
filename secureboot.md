# (Work in Progress) Adding Secureboot to a System that boots via Efistub 

https://nwildner.com/posts/2020-07-04-secure-your-boot-process/
https://wiki.gentoo.org/wiki/User:Sakaki/Sakaki%27s_EFI_Install_Guide

This Document will help to install my own Keys, sign the kernel (which will not be secured. ie. it will still load unsigned modules)
also I still want to be able to boot Windows, so Microsofts keys have to be added to db.

This is just because i'd like to know how things work, especially how to keep windows still booting in secureboot mode despite using my own keys. To make this a really secure setup you would have to:
- Password protect the uefi, so secureboot can not be disabled
- Store the PK encrypted
- Force kernel signature validation, so only signed modules will be loaded

## Explanation

There are four main EFI “variables” used to create a basic secureboot Root of Trust environment:
 - PK: The Platform Key, the master one, the ring to rule them all. The holder of a PK can install a new PK and update the KEK.
 - KEK: Key Exchange Key is a secondary key used to sign EFI executables directly or a key used to signd the db and dbx databases.
 - db: The signature databse is a list with all allowed signing certificates or criptografy hashes to allowed binaries. We will use THIS db key to sign our Linux Kernel.
 - dbx: The dark side of the db. Inverse db. “not-good-db”. You name it. It’s the list containing all keys that are not allowed.

## Boot System with systemd-boot kernel efi image
this will create an all in one kernel + initrd efi bootable image that can be signed later on

### Get systemd Efistubs

```bash
echo "sys-apps/systemd gnuefi" >> /etc/portage/package.use/systemd
emerge -1 systemd
```

### create /etc/kernel/cmdline

```bash
echo "dozfs root=ZFS=system/ROOT/coyote quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3" >> /etc/kernel/cmdline
```

### create new combined kernel + initrd image
download and run [efiprepare.sh](./root/bin/efiprepare.sh) 

```bash
efiprepare.sh --kver 5.17.7-gentoo-dist
```

### create efi boot entry for new image
```bash
efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0000 -L "Gentoo" -l '\EFI\gentoo\linux.efi' 
```

## Key creation

before this script can run, check if app-crypt/efitools are installed, if not do so now otherwise tools like "sign-efi-sig-list" are missing

```bash
su - root
mkdir /etc/efi-keys
chmod 700 /etc/efi-keys
cd /etc/efi-keys
wget https://www.rodsbooks.com/efi-bootloaders/mkkeys.sh
chmod 700 mkkeys.sh
./mkkeys.sh
```

using this script

<details>
 <summary>key generation script</summary>
 
```bash
 #!/bin/bash
# Copyright (c) 2015 by Roderick W. Smith
# Licensed under the terms of the GPL v3

echo -n "Enter a Common Name to embed in the keys: "
read NAME

openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME PK/" -keyout PK.key \
        -out PK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME KEK/" -keyout KEK.key \
        -out KEK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME DB/" -keyout DB.key \
        -out DB.crt -days 3650 -nodes -sha256
openssl x509 -in PK.crt -out PK.cer -outform DER
openssl x509 -in KEK.crt -out KEK.cer -outform DER
openssl x509 -in DB.crt -out DB.cer -outform DER

GUID=`python3 -c 'import uuid; print(str(uuid.uuid1()))'`
echo $GUID > myGUID.txt

cert-to-efi-sig-list -g $GUID PK.crt PK.esl
cert-to-efi-sig-list -g $GUID KEK.crt KEK.esl
cert-to-efi-sig-list -g $GUID DB.crt DB.esl
rm -f noPK.esl
touch noPK.esl

sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK noPK.esl noPK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt KEK KEK.esl KEK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k KEK.key -c KEK.crt db DB.esl DB.auth

chmod 0600 *.key

echo ""
echo ""
echo "For use with KeyTool, copy the *.auth and *.esl files to a FAT USB"
echo "flash drive or to your EFI System Partition (ESP)."
echo "For use with most UEFIs' built-in key managers, copy the *.cer files;"
echo "but some UEFIs require the *.auth files."
echo ""
```
</details>

### Saving old keys
```bash
mkdir -p /etc/efi-keys/old
cd /etc/efi-keys/old
 
efi-readvar -v PK -o old_PK.esl
efi-readvar -v KEK -o old_KEK.esl
efi-readvar -v db -o old_db.esl
efi-readvar -v dbx -o old_dbx.esl 
```

## Dual boot with windows
To dual boot with Windows, you would need to add Microsoft's certificates to the Signature Database. Microsoft has two db certificates:

- [Microsoft Windows Production PCA 2011 for Windows](./MicWinProPCA2011_2011-10-19.crt)
- [Microsoft Corporation UEFI CA 2011 for third-party binaries like UEFI drivers, option ROMs etc.](./MicCorUEFCA2011_2011-06-27.crt)

Create EFI Signature Lists from Microsoft's DER format certificates using Microsoft's GUID (77fa9abd-0359-4d32-bd60-28f4e78f784b) and combine them in one file for simplicity:

```bash
sbsiglist --owner 77fa9abd-0359-4d32-bd60-28f4e78f784b --type x509 --output MS_Win_db.esl MicWinProPCA2011_2011-10-19.crt
sbsiglist --owner 77fa9abd-0359-4d32-bd60-28f4e78f784b --type x509 --output MS_UEFI_db.esl MicCorUEFCA2011_2011-06-27.crt
cat MS_Win_db.esl MS_UEFI_db.esl > MS_db.esl
```
Sign a db update with your KEK. Use sign-efi-sig-list with option -a to add not replace a db certificate:
```bash
sign-efi-sig-list -a -g 77fa9abd-0359-4d32-bd60-28f4e78f784b -k KEK.key -c KEK.crt db MS_db.esl add_MS_db.auth
``

## installing keys
copy keys to an usb stick
*.esl and *.auth 

Now, add your keys following this order:
 Select the db entry, hit “Add new key”, and point to DB.esl
 Select the kek entry, hit “Add new key” and point to KEK.esl
 Finally, add the Platform Key(PK), select “Replace Keys” and point to PK.auth

