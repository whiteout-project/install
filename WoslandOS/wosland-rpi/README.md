# WoslandOS — Raspberry Pi

> For x86/Proxmox see [wosland-x86/](../wosland-x86/README.md) | Root overview: [README](../README.md)

Automated Ubuntu Server image for Raspberry Pi 4/5 that installs and configures WOSBot, SSH, VNC, and a web control panel on first boot.

---

## What Gets Installed

| Component | Details |
|---|---|
| OS | Ubuntu Server 24.04 LTS (arm64) |
| User | `wosland` / `W0sL@nd` |
| Hostname | `Wosland-os-server` |
| WOSBot | Python bot, systemd service `wosbot` |
| Web panel | Flask app on port **8080** |
| VNC | x11vnc on port **5900** via virtual framebuffer |
| SSH | OpenSSH on port **22** |
| Wallpaper | WoslandOS background image |

---

## Quick Start

### 1. Build the image

**Requirements:**
```bash
sudo apt install xz-utils kpartx qemu-user-static binfmt-support wget
```

```bash
cd wosland-rpi

# Optional: edit config.sh to update URLs or credentials
nano config.sh

sudo ./build.sh
# Output: ./output/wosland-os-YYYYMMDD.img.xz
```

To force a fresh base image download:
```bash
sudo ./build.sh --clean
```

### 2. Flash to SD card

**Raspberry Pi Imager (recommended):**
1. Open [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Choose OS → Use custom → select the `.img.xz`
3. Choose your SD card → Write

**Command line:**
```bash
xzcat output/wosland-os-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. First boot

Insert SD card, power on, and wait **5–10 minutes**. The Pi sets itself up and reboots once when done. Access via:

| Service | Address |
|---|---|
| Web panel | `http://<pi-ip>:8080` |
| SSH | `ssh wosland@<pi-ip>` |
| VNC | `<pi-ip>:5900` (password: `W0sL@nd`) |

> Find the Pi's IP in your router's DHCP list, or connect a monitor.

---

## Web Control Panel

Open `http://<pi-ip>:8080` to manage the bot without SSH.

- Start / Stop / Restart the wosbot service
- Paste and save a new bot token (auto-restarts the service)
- Live log viewer
- Service status at a glance

**API:**
```bash
curl http://<pi-ip>:8080/api/status
curl http://<pi-ip>:8080/api/logs?lines=200
```

---

## Updating the Bot Token

**Web panel (easiest):** `http://<pi-ip>:8080` → paste token → Save Token

**SSH:**
```bash
ssh wosland@<pi-ip>
echo "YOUR_TOKEN" > ~/bot/bot_token.txt
sudo systemctl restart wosbot
```

**Helper script (run on the Pi):**
```bash
sudo update-token.sh YOUR_TOKEN
```

**SCP from your local machine:**
```bash
echo "YOUR_TOKEN" > bot_token.txt
scp bot_token.txt wosland@<pi-ip>:~/bot/bot_token.txt
ssh wosland@<pi-ip> sudo systemctl restart wosbot
```

---

## Updating Repo Links

Edit only `config.sh`, then rebuild:

```bash
nano config.sh        # update BOT_MAIN_PY, BOT_INSTALL_PY, REPO_BASE, etc.
sudo ./build.sh
```

The Ubuntu base image version is auto-detected at build time — no manual URL updates needed.

---

## Service Management (SSH)

```bash
sudo systemctl status wosbot
sudo systemctl start | stop | restart wosbot
sudo journalctl -u wosbot -f

sudo systemctl status wosland-web
sudo systemctl status x11vnc
```

---

## File Locations on the Pi

| File | Path |
|---|---|
| Bot script | `/home/wosland/bot/main.py` |
| Bot token | `/home/wosland/bot/bot_token.txt` |
| Python venv | `/home/wosland/bot/venv/` |
| Wosbot service | `/etc/systemd/system/wosbot.service` |
| Web panel | `/opt/wosland-webserver/app.py` |
| Setup log | `/var/log/wosland-setup.log` |
| Wallpaper | `/usr/share/wallpapers/wosland/woslandOS.png` |

---

## Default Credentials

| Service | Username | Password |
|---|---|---|
| Linux / SSH | `wosland` | `W0sL@nd` |
| VNC | *(none)* | `W0sL@nd` |
| Web panel | *(no auth)* | — |

---

## Troubleshooting

**Setup not complete after 10+ minutes**
```bash
# Connect a monitor/keyboard and check
cat /var/log/wosland-setup.log
```

**Web panel not loading**
```bash
sudo systemctl status wosland-web
sudo journalctl -u wosland-web -n 50
```

**Bot not starting**
```bash
sudo systemctl status wosbot
sudo journalctl -u wosbot -n 50
cat ~/bot/bot_token.txt   # must contain a valid token
```

**VNC connection refused**
```bash
sudo systemctl restart xvfb x11vnc
sudo journalctl -u x11vnc -n 30
```

---

## License

MIT — see [LICENSE](LICENSE)
