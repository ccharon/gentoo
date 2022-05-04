# Vorhandene Gentoo Installation auf ZFS umstellen.

Alle Schritte vom Backup der alten Installation bis zum booten des umgestellten Systems

## Backup

livecd booten

```bash
mkdir -p /old/efi /old/boot /old/root /old/home
```

auf mannigfaltige art und weise die dateisysteme unter die verzeichnisse mounten,
wenn es keine boot partition gibt, einfach auslassen.

- evtl ist es hilfreich zu wissen wie man lvm volumes manuell einbindet: 
    falls nötig
    apt-get install lvm2
    vgscan

- dann die volume group(s) aktivieren
    vgchange -a y <nameDerVolumeGroup>

jetzt sind die volumes unter /dev/mapper/ verfügbar

### EFI Partition sichern
  
```bash
cd /old/efi
tar cvjf /backup/efi.tar.bz2 *
```
### Boot Partition sichern

```bash
cd /old/boot
tar cvjf /backup/boot.tar.bz2 *
```
### Root Partition sichern
cd /old/root
tar --exclude=dev/* \
--exclude=proc/* \
--exclude=sys/* \
--exclude=tmp/* \
--exclude=var/tmp/* \
--exclude=var/lock/* \
--exclude=var/log/* \
--exclude=var/run/* \
--exclude=lost+found \
-cvjf /backup/root.tar.bz2 *

### Home Partition sichern
cd /old/home
tar cvjf /backup/home.tar.bz2 *

## ZFS erstellen

Hier ist gemischt was mir gefällt aus der Gentoo Doku, Arch Doku und dem was ich auf einer Ubuntu 22.04 Installation sehen konnte.
Es wird folgendes Layout erstellt:

SSD (GPT) nvme1n1
   |
   ├── nvme1n1p1 EFI(fat32) /boot/efi und bind mount /boot/efi/grub nach /boot/grub
   |
   ├── nvme1n1p2 SWAP(swap) swap
   |
   ├── nvme1n1p3 bpool(ZPOOL)
   |   └── BOOT none
   |       └── coyote /boot
   |
   └── nvme1n1p4 rpool(ZPOOL)
       ├── ROOT none
       |   ├── coyote /
       |   ├── coyote/srv /srv
       |   ├── coyote/usr /usr
       |   ├── coyote/usr/local /usr/local
       |   ├── coyote/var /var
       |   ├── coyote/var/lib /var/lib
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
           
### Platte leeren und Partitionen anlegen
```bash
sgdisk --zap-all /dev/nvme1n1

# 512MiB EFI Partition
sgdisk -n1:1M:+512M -t1:EF00 /dev/nvme1n1

# 64G SWAP Partition
sgdisk -n2:0:+64G -t2:8200 /dev/nvme1n1

# 2G bpool Partition
sgdisk -n3:0:+2G -t3:BE00 /dev/nvme1n1
  
# Rest rpool
sgdisk -n4:0:0 -t4:BF00 $DISK  
```
  
  ### EFI Partition
  
  ### SWAP Parition
  
  ### BPOOL Parititon
  #### BPOOL
  ```bash
  zpool create -d -o feature@allocation_classes=enabled \
                  -o feature@async_destroy=enabled      \
                  -o feature@bookmarks=enabled          \
                  -o feature@embedded_data=enabled      \
                  -o feature@empty_bpobj=enabled        \
                  -o feature@enabled_txg=enabled        \
                  -o feature@extensible_dataset=enabled \
                  -o feature@filesystem_limits=enabled  \
                  -o feature@hole_birth=enabled         \
                  -o feature@large_blocks=enabled       \
                  -o feature@lz4_compress=enabled       \
                  -o feature@project_quota=enabled      \
                  -o feature@resilver_defer=enabled     \
                  -o feature@spacemap_histogram=enabled \
                  -o feature@spacemap_v2=enabled        \
                  -o feature@userobj_accounting=enabled \
                  -o feature@zpool_checkpoint=enabled   \
                  bpool $VDEVS
  ```
  
  ### RPOOL Partition
  #### RPOOL
  
  ### Datasets in den Pools
  