# WoslandOS

Automated installer for **WOSBot** — available for Raspberry Pi and x86-64 machines (bare metal, VMs, Proxmox LXC).

Both variants install the same stack automatically on first boot:
- WOSBot (Python, systemd service, auto-updates)
- SSH (port 22), VNC (port 5900), Desktop environment with wallpaper
- Web control panel (port 8080) — manage service, update token, view logs

---

## Repository Layout

```
WoslandOS/
│
├── README.md                  <- You are here
├── LICENSE
├── .gitignore
│
├── wosland-rpi/               <- Raspberry Pi (arm64)
│   ├── config.sh              <- Edit this to update URLs / credentials
│   ├── build.sh               <- Produces a .img.xz for Pi SD card
│   ├── update-token.sh        <- Helper to update bot token on the Pi
│   ├── rootfs-overlay/        <- Files injected into the image
│   ├── webserver/app.py       <- Web control panel (Flask)
│   └── README.md
│
└── wosland-x86/               <- x86-64: bare metal / VM / Proxmox LXC
    ├── config.sh              <- Edit this to update URLs / credentials
    ├── build-iso.sh           <- Produces a fully unattended bootable ISO
    ├── build-lxc.sh           <- Creates & provisions a Proxmox LXC container
    ├── iso-builder/           <- Autoinstall (cloud-init) templates
    ├── rootfs-overlay/        <- Files injected into target system
    ├── webserver/app.py       <- Web control panel (Flask)
    └── README.md
```

---

## Quick Pick

| I want to install on... | Use |
|---|---|
| Raspberry Pi 4 / 5 | [wosland-rpi/](wosland-rpi/README.md) |
| Old PC / laptop | [wosland-x86/](wosland-x86/README.md) — ISO method |
| Proxmox VM | [wosland-x86/](wosland-x86/README.md) — ISO method |
| Proxmox LXC container | [wosland-x86/](wosland-x86/README.md) — LXC method |

---

## Web Control Panel (all variants)

After installation, open `http://<machine-ip>:8080` in any browser.

| Action | How |
|---|---|
| Start / Stop / Restart bot | Buttons in the Service card |
| Update bot token | Paste in Bot Token card, click Save (auto-restarts bot) |
| View live logs | Recent Logs card — last 80 lines |
| Check service status | Green = running, Red = stopped/failed |

---

## Updating Repo Links

Each variant has its own `config.sh`. When bot URLs change, edit the relevant file and rebuild:

```bash
# Raspberry Pi
nano wosland-rpi/config.sh
sudo wosland-rpi/build.sh

# x86 ISO
nano wosland-x86/config.sh
sudo wosland-x86/build-iso.sh

# x86 Proxmox LXC
nano wosland-x86/config.sh
sudo wosland-x86/build-lxc.sh
```

---

## Default Credentials

| Service | Username | Password |
|---|---|---|
| Linux / SSH | `wosland` | `W0sL@nd` |
| VNC | *(none)* | `W0sL@nd` |
| Web panel | *(no auth)* | — |

> Change the password after first login with `passwd`.

---

## License

MIT — see [LICENSE](LICENSE)
