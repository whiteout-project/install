> 📖 **This README covers the Raspberry Pi variant.** For x86/Proxmox see [`wosland-x86/README.md`](wosland-x86/README.md). For a full overview see the root [`README.md`](../README.md).

---

# WoslandOS — Raspberry Pi Auto-Install Image

A minimal Ubuntu Server image for Raspberry Pi that automatically installs and configures **WOSBot**, SSH, VNC, and a web-based control panel — all on first boot.

---

## 📋 What Gets Installed

| Component | Details |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS (arm64, Raspberry Pi) |
| **User** | `wosland` / `W0sL@nd` |
| **Hostname** | `Wosland-os-server` |
| **WOSBot** | Python bot, runs as systemd service `wosbot` |
| **Web Control Panel** | Flask app on port **8080** — manage service, update token |
| **VNC** | x11vnc on port **5900**, virtual framebuffer via Xvfb |
| **SSH** | OpenSSH on port **22** |
| **Background** | Custom WoslandOS wallpaper |

---

## ⚡ Quick Start — Flash & Boot

### 1. Download the pre-built image

Grab the latest `.img.xz` from the **Releases** tab.

### 2. Flash to SD card

**Option A — Raspberry Pi Imager (recommended)**
1. Open [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Choose OS → "Use custom" → select the `.img.xz` file
3. Choose your SD card
4. Click Write

**Option B — command line**
```bash
xzcat wosland-os-YYYYMMDD.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```
Replace `/dev/sdX` with your SD card device (`lsblk` to find it).

### 3. First boot

1. Insert SD card into Raspberry Pi and power on
2. Wait **5–10 minutes** for the automatic setup to complete (the Pi reboots once when done)
3. The Pi will be accessible via:
   - **SSH**: `ssh wosland@<pi-ip-address>`
   - **Web Panel**: `http://<pi-ip-address>:8080`
   - **VNC**: `<pi-ip-address>:5900` (password: `W0sL@nd`)

> **Finding the Pi's IP**: Check your router's DHCP list, or connect a monitor — the IP is shown at the login prompt.

---

## 🌐 Web Control Panel

Open `http://<pi-ip-address>:8080` in your browser.

![Web Panel Screenshot](docs/webpanel-preview.png)

### What you can do

| Action | How |
|---|---|
| **Start / Stop / Restart** the bot | Click the buttons in the "WOSBot Service" card |
| **Update the bot token** | Paste your token in the "Bot Token" card and click Save |
| **View live logs** | The "Recent Logs" card shows the last 80 lines of journald output |
| **See service status** | Green pill = running, red = stopped/failed |

Saving a new token **automatically restarts the bot** so it picks up the change immediately.

### API endpoints

The panel also exposes a simple JSON API for scripting:

```bash
# Check service status
curl http://<pi-ip>:8080/api/status

# Fetch last 200 log lines
curl http://<pi-ip>:8080/api/logs?lines=200
```

---

## 🔑 Updating the Bot Token

### Via the web panel (easiest)
1. Go to `http://<pi-ip>:8080`
2. Paste your token in the **Bot Token** field
3. Click **Save Token** — the service restarts automatically

### Via SSH
```bash
ssh wosland@<pi-ip-address>
echo "YOUR_NEW_TOKEN_HERE" > ~/bot/bot_token.txt
sudo systemctl restart wosbot
```

### Via SCP (from your local machine)
```bash
echo "YOUR_NEW_TOKEN_HERE" > bot_token.txt
scp bot_token.txt wosland@<pi-ip-address>:~/bot/bot_token.txt
ssh wosland@<pi-ip-address> sudo systemctl restart wosbot
```

---

## 🛠️ Building the Image Yourself

### Prerequisites

A Linux machine (Ubuntu/Debian recommended) with:

```bash
sudo apt install xz-utils kpartx qemu-user-static binfmt-support wget curl
```

> ARM emulation via QEMU is used so you can build on an x86 machine.

### Steps

```bash
# 1. Clone this repository
git clone <this-repo>
cd wosland-os

# 2. (Optional) Edit config.sh to update any URLs or credentials
nano config.sh

# 3. Build
sudo ./build.sh

# Output image will be in ./output/wosland-os-YYYYMMDD.img.xz
```

To force a fresh download of the Ubuntu base image:
```bash
sudo ./build.sh --clean
```

### Build output

```
wosland-os/
├── config.sh                   ← EDIT THIS when links change
├── build.sh                    ← Main build script
├── rootfs-overlay/             ← Files copied into the image
│   ├── usr/local/bin/
│   │   └── wosland-firstboot.sh  ← Runs on first boot
│   └── etc/systemd/system/
│       └── wosland-firstboot.service
├── webserver/
│   └── app.py                  ← Web control panel (Flask)
└── output/                     ← Built images appear here
```

---

## 🔄 Updating Repo Links

When the bot's repository URLs change, **only edit `config.sh`** — then rebuild:

```bash
# Open config.sh and update these variables:
BOT_MAIN_PY="https://raw.githubusercontent.com/..."
BOT_INSTALL_PY="https://raw.githubusercontent.com/..."
REPO_BASE="https://raw.githubusercontent.com/..."

# Rebuild
sudo ./build.sh
```

---

## 🔌 Service Management (SSH)

```bash
# Check bot status
sudo systemctl status wosbot

# Start / Stop / Restart
sudo systemctl start wosbot
sudo systemctl stop wosbot
sudo systemctl restart wosbot

# Follow live logs
sudo journalctl -u wosbot -f

# Check web panel
sudo systemctl status wosland-web

# Check VNC
sudo systemctl status x11vnc
```

---

## 🖥️ VNC Access

Connect with any VNC client (RealVNC, TigerVNC, etc.):

- **Host**: `<pi-ip-address>:5900`
- **Password**: `W0sL@nd`

The VNC server runs a virtual framebuffer (no physical display needed).

---

## 🔐 Default Credentials

| Service | Username | Password |
|---|---|---|
| Linux login / SSH | `wosland` | `W0sL@nd` |
| VNC | *(no username)* | `W0sL@nd` |
| Web panel | *(no auth)* | — |

> **Security note**: Change the password after first login with `passwd`. Consider adding a password to the web panel if the Pi is internet-facing.

---

## 📁 File Locations on the Pi

| File | Path |
|---|---|
| Bot main script | `/home/wosland/bot/main.py` |
| Bot token | `/home/wosland/bot/bot_token.txt` |
| Python venv | `/home/wosland/bot/venv/` |
| Wosbot service | `/etc/systemd/system/wosbot.service` |
| Web panel | `/opt/wosland-webserver/app.py` |
| Web panel service | `/etc/systemd/system/wosland-web.service` |
| Setup log | `/var/log/wosland-setup.log` |
| Wallpaper | `/usr/share/wallpapers/wosland/woslandOS.png` |

---

## 🐛 Troubleshooting

**Setup seems stuck / Pi not accessible after 10+ minutes**
```bash
# Connect monitor/keyboard and check the setup log
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
# Make sure bot_token.txt has a valid token
cat ~/bot/bot_token.txt
```

**VNC connection refused**
```bash
sudo systemctl status x11vnc
sudo systemctl restart xvfb x11vnc
```

---

## 📜 License

MIT — see [LICENSE](LICENSE)
