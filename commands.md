# Wichtige Befehle die man nicht vergesssen sollte :)

## initrd aktualisieren
```bash
dracut --kver 5.10.15 --force
``` 

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
