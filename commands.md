# Wichtige Befehle die man nicht vergesssen sollte :)

## dracut (initrd bauen)

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
