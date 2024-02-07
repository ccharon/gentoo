# Vorhandene Gentoo Installation auf ZFS umstellen. 

(geht auch als Neuinstallation, macht man halt kein Backup + Restore sondern legt die Strukturen an und entpackt dann eine Stage3 und macht alles wie im Handbuch, beim Kernel usw. dann das was hier steht)

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
   └── nvme1n1p3 system(ZPOOL)
       ├── ROOT none
       |   ├── coyote /
       |   ├── coyote/tmp /tmp
       |   ├── coyote/var/cache/distfiles /var/cache/distfiles
       |   ├── coyote/var/lib/libvirt /var/lib/libvirt
       |   ├── coyote/var/lib/docker /var/lib/docker
       |   └── coyote/var/log /var/log
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
  
# Rest system
sgdisk -n3:0:0 -t3:BF00 /dev/nvme1n1
```

Falls ein Mirror zfs gebaut wird dann Start und Endsektor der system partition rausfinden, fdisk und dann gucken... und dann:
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
  
### system
    evtl kann man hier auch ein Mirror erzeugen die letzte zeile lautet dann  system mirror /dev/nvme1n1p3 /dev/nvme2n1p3. Auf dem echten System sollte man auch darauf achten beim zpool die Devices am besten by-id zu nehmen. (/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_SXXXXXXXXXXXXXX-part3 )
```bash
zpool create \
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
    system /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_SXXXXXXXXXXXXXX-part3
```  
    
### Datasets in den Pools
```bash
cat << EOF > /tmp/mkdatasets.sh
#!/bin/bash

# root Dateisystem und Zeug
zfs create -o canmount=off -o mountpoint=none system/ROOT
zfs create -o canmount=noauto -o mountpoint=/ system/ROOT/coyote
zfs mount system/ROOT/coyote

zfs create -o com.sun:auto-snapshot=false system/ROOT/coyote/tmp
chmod 1777 /mnt/tmp

zfs create -o canmount=off system/ROOT/coyote/var
zfs create system/ROOT/var/log
zfs create system/ROOT/var/spool

zfs create -o canmount=off system/ROOT/coyote/var/lib
zfs create system/ROOT/coyote/var/lib/libvirt
zfs create system/ROOT/coyote/var/lib/docker

zfs create -o canmount=off system/ROOT/coyote/var/cache
zfs create -o system/ROOT/var/cache/distfiles
zfs create -o com.sun:auto-snapshot=false system/ROOT/coyote/var/temp

zfs create -o canmount=off -o mountpoint=none system/USERDATA    
zfs create -o mountpoint=/home/user system/USERDATA/user
zfs create -o mountpoint=/root system/USERDATA/root
chmod 700 /mnt/root

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
cp /etc/zfs/zpool.cache /mnt/etc/zfs

mount --make-private --rbind /dev  /mnt/dev && mount --make-private --rbind /proc /mnt/proc && mount --make-private --rbind /run /mnt/run && mount --make-private --rbind /sys  /mnt/sys

chroot /mnt /bin/bash --login
```

### im System
```bash
source /etc/profile
env-update
```
#### fstab anpassen
```bash

# zfs root wegen bug https://github.com/openzfs/zfs/issues/9461 nochmal extra in die fstab
echo "# Dateisystem nochmal mounten workaround Bug https://github.com/openzfs/zfs/issues/9461" >> /etc/fstab
echo "system/ROOT/coyote                           /          zfs    defaults   0  0" >> /etc/fstab

# efi partition einbinden
echo "UUID=`blkid -s UUID -o value /dev/nvme1n1p1`   /boot/efi  vfat  umask=0077 0  2" >> /etc/fstab

# swap partition einbinden
echo "UUID=`blkid -s UUID -o value /dev/nvme1n1p2`   none  swap  sw 0  0" >> /etc/fstab
```
alle alten Partitionen aus der fstab löschen (zfs übernimmt das mounten selbst)

#### System bootfähig machen
1. dracut konfigurieren /etc/dracut.conf.d/10-modules.conf zfs als modul hinzufügen

2. ggf. altes Zeugs aus der /etc/crypttab auskommentieren

3. Systemd mit gnuefi Unterstützung neu bauen (efistubs werden von unifiedkrnl.sh in Schritt 5 benötigt)

```bash
echo "sys-apps/systemd gnuefi" >> /etc/portage/package.use/systemd
emerge -1 systemd
```

3a. Falls die Datei /etc/hostid nicht existiert, die aktuelle hostid nach /etc/hostid schreiben.
Sonst kommt es später zu Problemen beim mounten der pools .. sowas wie die hostid war aber eine andere, ich will nicht ...

```bash
printf $(hostid | sed 's/\(..\)\(..\)\(..\)\(..\)/\\x\4\\x\3\\x\2\\x\1/') > /etc/hostid
```
4a. Kernel Parameter nach /etc/kernel/cmdline

```bash
echo "root=zfs:AUTO quiet splash" >> /etc/kernel/cmdline
```

4b. root Dateisystem im Parameter bootfs im pool angeben, damit das zfs:AUTO funktioniert

```bash
zpool set bootfs=system/ROOT/coyote system
```

5. kernel + initrd an die richtige Stelle kopieren
Das Script [unifiedkrnl.sh](./root/bin/unifiedkrnl.sh) runterladen und irgendwo hinlegen wo root gut rankommt.
Dieses Script kann benutzt werden um nachdem ein neuer Kernel gebaut wurde, diesen an die richtige Stelle zu kopieren. Evtl. reinschauen ob man an den Variablen was anpassen muss. Ansonsten jetzt gleich und immer wenn es einen neuen Kernel gibt:

```bash
unifiedkrnl.sh -a
```

6. efibootmgr sagen er soll den kernel direkt booten 

```bash
efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0000 -L "Gentoo" -l '\EFI\gentoo\linux.efi'
efibootmgr -d /dev/nvme1n1 -p 1 -c -b 0004 -L "Gentoo Previous Kernel" -l '\EFI\gentoo\linux.old'
``` 

## Nacharbeiten

### Regelmäßig scrub ausführen

In das lokale Repository das [systemd-zpool-scrub-1.1.ebuild](./var/db/repos/local/sys-fs/systemd-zpool-scrub/systemd-zpool-scrub-1.1.ebuild) einfügen und bauen.

danach kann man mit foldenden Befehlen einen wöchentlichen scrub planen
```bash
systemctl daemon-reload
systemctl enable --now zpool-scrub@system.timer
```
hat man mehr als den system dann für die anderen pools den Befehl mit dem jeweilingen Poolnamen wiederholen

### Automatisierte Snapshots mit sanoid
dazu in das lokale Repository das [sanoid.2.1.0.ebuild](./var/db/repos/local/sys-fs/sanoid/sanoid-2.1.0.ebuild) einfügen und bauen.

Diese Konfiguration sichert ROOT und USERDATA (rekursiv, alle datasets die unter ROOT oder USERDATA liegen bekommen snapshots)
```
#############################################################
# Sample config /usr/share/doc/sanoid-2.1.0/sanoid.conf.bz2 #
#############################################################

[system/ROOT]
	use_template = production
	recursive = zfs

[system/USERDATA]
	use_template = production
	recursive = zfs

#############################
# templates below this line #
#############################

[template_production]
	frequently = 0
	hourly = 36
	daily = 30
	monthly = 3
	yearly = 0
	autosnap = yes
	autoprune = yes
```
