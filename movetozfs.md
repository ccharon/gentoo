# Vorhandene Gentoo Installation auf ZFS umstellen.

Alle Schritte vom Backup der alten Installation bis zum booten des umgestellten Systems

## Backup

### alle daten sichern
Direkt im laufenden System sichern, wenn alle Dateisysteme gemounted sind, erwischt man damit alles. später beim Restore mounted man einfach auch alle Dateisysteme und alles wird direkt richtig neu verteilt :)
    

```bash 
# tar hat sich irgendwie zickig mit der Reihenfolge der Parameter und der Syntax der Excludes
# mit bisschen probieren ging es so.
cd / && tar -cJv \
--exclude=/dev/* \
--exclude=/proc/* \
--exclude=/home/* \
--exclude=/daten/* \
--exclude=/sys/* \
--exclude=/tmp/* \
--exclude=/var/tmp/* \
--exclude=/var/lock/* \
--exclude=/var/log/* \
--exclude=/var/cache/distfiles/* \
--exclude=/var/lib/libvirt/* \
--exclude=/var/run/* \
--exclude=/lost+found \
--exclude=/root.tar.xz \
-f /root.tar.xz /*
```

die Datei root.tar.xz irgendwo extern sichern oder gleich beim erstellen auf einen externen Datenträger packen
    
## ZFS erstellen

Hier ist gemischt was mir gefällt aus der Gentoo Doku, Arch Doku und dem was ich auf einer Ubuntu 22.04 Installation sehen konnte.
https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html#ubuntu-installer
https://wiki.archlinux.org/title/ZFS
    
Das Setup wird ein wenig speziell, gebootet wird indem der kernel direk von der Firmware geladen wird, d.h.: kein extra Bootloader wie Grub    
Es wird folgendes Layout erstellt:
```
SSD (GPT) nvme1n1
   |
   ├── nvme1n1p1 EFI(fat32) /boot/efi
   |
   ├── nvme1n1p2 SWAP(swap) swap
   |
   └── nvme1n1p3 rpool(ZPOOL)
       ├── ROOT none
       |   ├── coyote /
       |   ├── coyote/srv /srv
       |   ├── coyote/usr /usr
       |   ├── coyote/usr/local /usr/local
       |   ├── coyote/var /var
       |   ├── coyote/var/lib /var/lib
       |   ├── coyote/var/lib/libvirt /var/lib/libvirt
       |   ├── coyote/var/lib/portage /var/lib/portage
       |   ├── coyote/var/lib/AccountsService /var/lib/AccountsService
       |   ├── coyote/var/lib/NetworkManager /var/lib/NetworkManager
       |   ├── coyote/var/db /var/db
       |   ├── coyote/var/log /var/log
       |   ├── coyote/var/spool /var/spool
       |   └── coyote/var/www /var/www
       | 
       └── USERDATA none
           ├── user /home/user
           └── root /root
```
### Live CD booten

### Platte leeren und Partitionen anlegen
```bash
# Das zerlegt ALLES auf de Platte! VORSICHT!
sgdisk --zap-all /dev/nvme1n1

# 512MiB EFI Partition
sgdisk -n1:1M:+512M -t1:EF00 /dev/nvme1n1

# 64G SWAP Partition
sgdisk -n2:0:+64G -t2:8200 /dev/nvme1n1
  
# Rest rpool
sgdisk -n3:0:0 -t3:BF00 /dev/nvme1n1
```

Falls ein Mirror zfs gebaut wird dann Start und Endsektor der rpool partition rausfinden, fdisk und dann gucken... und dann:
```bash
sgdisk -n3:startsektor:endsektor -t3:BF00 /dev/nvme2n1
```

  
### EFI Partition

```bash
mkfs.fat -F32 -n EFI /dev/nvme1n1p1
```

### SWAP Partition

```bash
mkswap /dev/nvme1n1p2
```
  
### RPOOL
    evtl kann man hier auch ein Mirror erzeugen die letzte zeile lautet dann  rpool mirror /dev/nvme1n1p3 /dev/nvme2n1p3. Auf dem echten System sollte man auch darauf achten beim zpool die Devices am besten by-id zu nehmen. (/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_SXXXXXXXXXXXXXX-part3 )
```bash
zpool create \
    -o cachefile=/etc/zfs/zpool.cache \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl 
    -O canmount=off \
    -O compression=lz4 \
    -O aclinherit=passthrough \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/ \
    -R /mnt \
    rpool /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_SXXXXXXXXXXXXXX-part3
```  
    
### Datasets in den Pools
```bash
cat << EOF > /tmp/mkdatasets.sh
#!/bin/bash

# root Dateisystem und Zeug
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o mountpoint=/ rpool/ROOT/coyote
zfs create -o mountpoint=/srv rpool/ROOT/coyote/srv
zfs create -o mountpoint=/usr rpool/ROOT/coyote/usr
zfs create -o mountpoint=/usr/local rpool/ROOT/coyote/usr/local
zfs create -o mountpoint=/var rpool/ROOT/coyote/var
zfs create -o mountpoint=/var/lib rpool/ROOT/coyote/var/lib
zfs create -o mountpoint=/var/lib/portage rpool/ROOT/coyote/var/lib/portage
zfs create -o mountpoint=/var/lib/AccountsService rpool/ROOT/coyote/var/lib/AccountsService
zfs create -o mountpoint=/var/lib/libvirt rpool/ROOT/coyote/var/lib/libvirt
zfs create -o mountpoint=/var/lib/NetworkManager rpool/ROOT/coyote/var/lib/NetworkManager
zfs create -o mountpoint=/var/db rpool/ROOT/coyote/var/db
zfs create -o mountpoint=/var/log rpool/ROOT/coyote/var/log
zfs create -o mountpoint=/var/spool rpool/ROOT/coyote/var/spool
zfs create -o mountpoint=/var/www rpool/ROOT/coyote/var/www

# home Verzeichnisse
zfs create -o canmount=off -o mountpoint=none rpool/USERDATA    
zfs create -o mountpoint=/home/user rpool/USERDATA/user
zfs create -o mountpoint=/root rpool/USERDATA/root

EOF


# dann
/tmp/mkdatasets.sh
rm /tmp/mkdatasets.sh

```

## Daten zurück sichern

Jetzt sollte unter /mnt alles mögliche eingebunden sein. was noch fehlt ist das EFI Verzeichnis

### EFI Verzeichnis einbinden
```bash
# in der fstab wird es dann mit richtigen Berechtigungen gemouted, jetzt reicht das hier
mount /dev/nvme1n1p1 /mnt/boot/efi
```
### backup entpacken

```bash
cd /mnt
tar xpvf /backup/root.tar.xz --xattrs-include='*.*' --numeric-owner
```

## System wieder flott machen
### chroot
```bash
mount --make-private --rbind /dev  /mnt/dev && mount --make-private --rbind /proc /mnt/proc && mount --make-private --rbind /run /mnt/run && mount --make-private --rbind /sys  /mnt/sys

chroot /mnt /bin/bash --login
```

### im System
```bash
source /etc/profile
env-update
```
#### fstab anpassen
- efi partition einbinden
- swap partition einbinden
- alle anderen patitionen aus der fstab löschen (zfs übernimmt das mounten selbst)

#### system bootfähig machen
- dracut konfigurieren /etc/dracut.conf.d/10-modules.conf zfs als modul hinzufügen
- kernel + initrd nach /boot/efi/EFI/gentoo kopieren (am besten als kernel.efi und initrd.img) Versionen weglassen weil dann der efi boot eintrag immer gleich bleiben kann :)
- efibootmgr sagen er soll den kernel direkt booten 
```bash
efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0000 -L "Gentoo" -l "\gentoo\kernel.efi" initrd="initrd.img' --unicode "root=ZFS=rpool/ROOT/coyote"
``` 
