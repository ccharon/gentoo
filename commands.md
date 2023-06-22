# Wichtige Befehle die man nicht vergesssen sollte :)
## initrd neu bauen wenn man dist-kernel und unified kernel images verwendet
einfach die config Phase von sys-kernel/gentoo-kernel ausführen
```bash
emerge --config sys-kernel/gentoo-kernel
```
alternativ (nimmt den Kernel der unter /usr/src/linux verlinkt ist 

```bash
kv="$(k=$(readlink /usr/src/linux); echo "${k:6}")" && /usr/bin/dracut --force --kernel-image /usr/src/linux-${kv}/arch/x86/boot/bzImage /usr/src/linux-${kv}/arch/x86/boot/initrd ${kv}
```

## dracut (initrd bauen)
dracut holt sich seine infos vom System. wenn man will das die Tastatur das richtige Layout hat muss man es unter /etc/vconsole.conf einstellen
ausserdem sollten die notwendigen tools installiert sein lvm, btrfs-utils, cryptsetup sonst klappt das mounten nicht.
plymouth ist für grafik zuständig.

## automatisch kernel image aktualisieren nachdem zfs-kmod gebaut wurde
Sollte man eigentlich nicht brauchen wenn man das use flag "dist-kernel" am zfs-kmod ebuild hat... nunja

diese function in die /etc/portage/bashrc (falls nicht existiert anlegen), falls es die function schon gibt, den Inhalt hinzufügen
```bash
function post_pkg_postinst() {
  if test "$CATEGORY/$PN" = "sys-fs/zfs-kmod"; then
    echo -e "\e[01;32m >>> Post-install hook: dracut <<<\e[00m"
    kv="$(k=$(readlink /usr/src/linux); echo "${k:6}")"

    /usr/bin/dracut --force --kernel-image /usr/src/linux-${kv}/arch/x86/boot/bzImage /usr/src/linux-${kv}/arch/x86/boot/initrd ${kv}
  fi
}
```

### initrd aktualisieren
```bash
dracut --kver 5.10.15 --force
``` 
### kernel parameter
diese Parameter müssen in die Grub Config mit rein /etc/default/grub anfügen bei GRUB_CMDLINE_LINUX
```bash
rd.luks.options=allow-discards rd.luks.uuid=<uuid des luks volumes auf dem die root partition liegt>
``` 
rd.luks.options=allow-discards -> erlaubt trim wenn man eine ssd hat

## snapper (btrfs snapshot tool) nach der Installation auch wirklich aktivieren
(wenn man systemd statt openrc nutzt)

Die Systemd Timer sind installiert aber nicht aktiv

```bash
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable snapper-boot.timer

systemctl start snapper-timeline.timer
systemctl start snapper-cleanup.timer
systemctl start snapper-boot.timer
```
