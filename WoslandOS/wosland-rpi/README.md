# WoslandOS — Raspberry Pi

> For x86 / Proxmox see [wosland-x86/README.md](../wosland-x86/README.md) | Back to [root README](../README.md)

Automated Ubuntu 24.04 image for Raspberry Pi 4 / 5 that sets up a Discord bot server on first boot — no keyboard, no monitor, no manual steps.

---

## System Requirements

| | Minimum | Recommended |
|---|---|---|
| **Model** | Raspberry Pi 4 (2 GB RAM) | Raspberry Pi 4 or 5 (4 GB+ RAM) |
| **Architecture** | arm64 | arm64 |
| **SD card** | 16 GB Class 10 | 32 GB+ A2-rated U3 |
| **Network** | Wi-Fi or wired Ethernet | Wired Ethernet (more stable) |
| **Power supply** | Official 5 V / 3 A USB-C | Official 5 V / 5 A (Pi 5) |
| **Internet** | Required during first boot | — |

> The Pi downloads packages and bot files on first boot. Make sure it has internet access before powering on.

---

## What Gets Installed

| Component | Details |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS (arm64), latest point release |
| **User account** | `wosland` / `W0sL@nd`, sudo access |
| **Hostname** | `Wosland-os-server` |
| **Desktop** | XFCE4, autologin, WoslandOS wallpaper |
| **Bot (default)** | Whiteout Survival Python bot, systemd service `wosbot` |
| **Node.js** | v22 LTS (pre-installed for JS bot) |
| **Web panel** | Flask, port **8080** |
| **VNC** | x11vnc, port **5900**, virtual framebuffer |
| **SSH** | OpenSSH, port **22** |
| **Desktop shortcut** | `WoslandOS Control Panel` opens the web panel in browser |

---

## Build Requirements

The image is built on a **Linux machine** (not on the Pi itself). A Debian/Ubuntu host is recommended.

```bash
sudo apt install xz-utils kpartx qemu-user-static binfmt-support wget curl git
```

> **Cross-compile note:** The build uses QEMU to run arm64 binaries during image assembly. On a native arm64 host (e.g. another Pi) you can skip `qemu-user-static`.

---

## Step 1 — Configure

Open `config.sh` and check the values. You only need to change this file if repo URLs or credentials have changed:

```bash
cd wosland-rpi
nano config.sh
```

Key values:

```bash
OS_USERNAME="wosland"           # Linux username
OS_PASSWORD="W0sL@nd"           # Linux + VNC password — change this!
OS_HOSTNAME="Wosland-os-server"

BOT_MAIN_PY="https://..."       # WOS Python bot source
BOT_INSTALL_PY="https://..."    # WOS Python install script
BOT_JS_REPO="https://..."       # WOS JS bot repo
BOT_KINGSHOT_REPO="https://..." # Kingshot bot repo

DEFAULT_BOT="wos-py"            # wos-py | wos-js | kingshot
UBUNTU_SERIES="24.04"           # auto-detects latest point release
```

---

## Step 2 — Build the Image

```bash
sudo ./build.sh
# Output: ./output/wosland-os-YYYYMMDD.img.xz
```

This downloads the latest Ubuntu 24.04 Pi image automatically, injects the configuration and scripts, and produces a compressed `.img.xz` ready to flash.

To force a fresh Ubuntu base image download (e.g. after a new point release):
```bash
sudo ./build.sh --clean
```

**Expected build time:** 5–15 minutes depending on your connection and whether the base image is cached.

---

## Step 3 — Flash to SD Card

### Option A — Raspberry Pi Imager (recommended for beginners)

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Click **Choose OS** → **Use custom** → select your `.img.xz` file
3. Click **Choose Storage** → select your SD card
4. Click the ⚙️ gear icon — you can optionally pre-configure Wi-Fi and SSH here
5. Click **Write**

### Option B — Command line (Linux / macOS)

```bash
# Replace /dev/sdX with your SD card device — check with lsblk first!
xzcat output/wosland-os-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

> **Warning:** Double-check the device path. `dd` will overwrite whatever you point it at.

### Option C — Balena Etcher (Windows / macOS / Linux)

1. Download [Balena Etcher](https://etcher.balena.io/)
2. Flash from file → select `.img.xz` → select SD card → Flash

---

## Step 4 — First Boot

1. Insert the SD card into the Pi
2. Connect Ethernet (recommended) or ensure Wi-Fi is pre-configured
3. Power on

The Pi will:
1. Boot into Ubuntu
2. Run `wosland-firstboot.sh` automatically (takes **5–15 minutes**)
3. Install all packages, bot, desktop, VNC, SSH, web panel
4. **Reboot automatically** when done

**How to find the Pi's IP address:**
- Check your router's DHCP client list
- Connect a monitor — the IP is shown after reboot
- Try `ping Wosland-os-server.local` from the same network (mDNS)

---

## Step 5 — Access the Pi

Once booted (wait for the automatic reboot to finish):

| Service | Address | Credentials |
|---|---|---|
| **Web panel** | `http://<pi-ip>:8080` | No login required |
| **SSH** | `ssh wosland@<pi-ip>` | Password: `W0sL@nd` |
| **VNC** | `<pi-ip>:5900` | Password: `W0sL@nd` |
| **Desktop shortcut** | Double-click `WoslandOS Control Panel` on desktop | — |

---

## Web Control Panel

Open `http://<pi-ip>:8080` to manage everything without SSH.

| Feature | How to use |
|---|---|
| **Start / Stop / Restart** | Buttons in the Service Control card |
| **Bot token** | Paste token in the Bot Token card → Save & Restart |
| **Switch bot** | Select a bot → Switch Bot → confirm twice |
| **Desktop toggle** | Enable or disable XFCE autostart on next boot |
| **Logs** | Scroll the Recent Logs card, or click ↺ to refresh |

### Switching Bots

The web panel supports three bots. Switching wipes the current bot directory, installs the new one, and carries your token over automatically.

| Bot | Notes |
|---|---|
| **Whiteout Survival (Python)** | Default. Uses `~/bot/bot_token.txt` |
| **Whiteout Survival (JS)** | Requires Node 22 (pre-installed). Token goes to `~/bot/src/.env` |
| **Kingshot** | Python bot. Uses `~/bot/bot_token.txt` |

Two confirmation dialogs are shown before any switch to prevent accidents.

---

## Updating the Bot Token

**Web panel (easiest):**
`http://<pi-ip>:8080` → Bot Token card → paste → **Save & Restart**

**SSH:**
```bash
ssh wosland@<pi-ip>
echo "YOUR_TOKEN_HERE" > ~/bot/bot_token.txt
sudo systemctl restart wosbot
```

**Helper script (run on the Pi):**
```bash
sudo /usr/local/bin/update-token.sh YOUR_TOKEN_HERE
```

**SCP from your local machine:**
```bash
echo "YOUR_TOKEN_HERE" > /tmp/bot_token.txt
scp /tmp/bot_token.txt wosland@<pi-ip>:~/bot/bot_token.txt
ssh wosland@<pi-ip> "sudo systemctl restart wosbot"
```

> If you are using the **JS bot**, write to `~/bot/src/.env` instead:
> ```bash
> echo "TOKEN=YOUR_TOKEN_HERE" > ~/bot/src/.env
> ```

---

## Service Management (SSH)

```bash
# Bot service
sudo systemctl status wosbot
sudo systemctl start wosbot
sudo systemctl stop wosbot
sudo systemctl restart wosbot
sudo journalctl -u wosbot -f           # follow live logs
sudo journalctl -u wosbot -n 100       # last 100 lines

# Web panel
sudo systemctl status wosland-web
sudo journalctl -u wosland-web -n 50

# VNC
sudo systemctl status xvfb
sudo systemctl status x11vnc
sudo systemctl restart xvfb x11vnc
```

---

## Desktop GUI

XFCE4 desktop autostarts by default. You can toggle this from the web panel (Desktop & GUI card) — takes effect on the next reboot.

Connect via VNC to see the desktop remotely:
- **Host:** `<pi-ip>:5900`
- **Password:** `W0sL@nd`
- Recommended VNC clients: [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/), [TigerVNC](https://tigervnc.org/), Remmina (Linux)

A **WoslandOS Control Panel** shortcut is on the desktop that opens the web panel in the browser.

---

## File Locations

| File | Path |
|---|---|
| Bot main script | `/home/wosland/bot/main.py` |
| Bot token (Python/Kingshot) | `/home/wosland/bot/bot_token.txt` |
| Bot token (JS) | `/home/wosland/bot/src/.env` |
| Active bot type | `/home/wosland/bot/.bot_type` |
| Python venv | `/home/wosland/bot/venv/` |
| Wosbot service | `/etc/systemd/system/wosbot.service` |
| Web panel | `/opt/wosland-webserver/app.py` |
| Bot switcher script | `/usr/local/bin/wosland-switch-bot.sh` |
| First-boot log | `/var/log/wosland-setup.log` |
| Bot switch log | `/var/log/wosland-switch.log` |
| Wallpaper | `/usr/share/wallpapers/wosland/woslandOS.png` |
| GUI flag | `/etc/wosland/gui_enabled` (exists = GUI on) |

---

## Default Credentials

| Service | Username | Password |
|---|---|---|
| Linux / SSH | `wosland` | `W0sL@nd` |
| VNC | *(none)* | `W0sL@nd` |
| Web panel | *(no auth required)* | — |

> Change the password immediately after first login: `passwd`

---

## Troubleshooting

**First boot stuck / not completing after 15+ minutes**
```bash
# Connect monitor + keyboard, or SSH in early, then:
sudo tail -f /var/log/wosland-setup.log
```

**Cannot find Pi on the network**
- Connect a monitor — the IP is shown after boot
- Check your router DHCP table for `Wosland-os-server`
- Try: `ping Wosland-os-server.local`

**Web panel not loading at port 8080**
```bash
sudo systemctl status wosland-web
sudo journalctl -u wosland-web -n 50
ss -tlnp | grep 8080
```

**Bot service not starting**
```bash
sudo systemctl status wosbot
sudo journalctl -u wosbot -n 50
cat ~/bot/bot_token.txt     # must contain a valid token — not empty
cat ~/bot/.bot_type         # check active bot type
```

**Bot switched but service failing**
```bash
# Check the switch log
sudo cat /var/log/wosland-switch.log

# Re-run the switch manually
sudo /usr/local/bin/wosland-switch-bot.sh wos-py
```

**VNC connection refused**
```bash
sudo systemctl restart xvfb
sleep 3
sudo systemctl restart x11vnc
sudo journalctl -u x11vnc -n 30
```

**Build fails — missing tools**
```bash
sudo apt install xz-utils kpartx qemu-user-static binfmt-support wget curl git
```

---

## License

MIT — see [LICENSE](LICENSE)
