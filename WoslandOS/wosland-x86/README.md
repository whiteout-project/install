# WoslandOS x86 / LXC

Same bot, desktop, VNC, SSH, and web panel as the Raspberry Pi image — but for **x86-64 machines**: old PCs, Proxmox LXC containers, and VMs.

---

## 📋 What Gets Installed

| Component | Details |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS (x86-64) |
| **Desktop** | XFCE4 (configurable: xfce / lxde / mate) |
| **User** | `wosland` / `W0sL@nd` |
| **Hostname** | `Wosland-os-server` |
| **WOSBot** | Python bot, runs as systemd service `wosbot` |
| **Web Panel** | Flask app on port **8080** |
| **VNC** | x11vnc on port **5900**, virtual display via Xvfb |
| **SSH** | OpenSSH on port **22** |
| **Background** | WoslandOS wallpaper set on the desktop |

---

## 🗂️ Choosing Your Install Method

| Method | Best for | Script |
|---|---|---|
| **ISO → bare metal** | Old PC, any physical machine | `build-iso.sh` |
| **ISO → Proxmox VM** | Proxmox, VirtualBox, VMware | `build-iso.sh` |
| **LXC → Proxmox** | Proxmox, lightweight containers | `build-lxc.sh` |

---

## ⚡ Method 1 — ISO (Bare Metal / VM)

### Build the ISO

**Requirements (on your Linux build machine):**
```bash
sudo apt install xorriso wget curl openssl
```

```bash
cd wosland-x86

# (Optional) edit config.sh to change URLs or credentials
nano config.sh

sudo ./build-iso.sh
# Output: ./output/wosland-os-x86-YYYYMMDD.iso
```

### Flash to USB (bare metal)
```bash
sudo dd if=output/wosland-os-x86-YYYYMMDD.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
Or use **Rufus** / **Ventoy** on Windows.

### Create a Proxmox VM from ISO
1. In Proxmox web UI → **Create VM**
2. OS tab → upload the ISO and select it
3. System tab → BIOS: **OVMF (UEFI)** recommended, or SeaBIOS
4. Disk: ≥ 20 GB, CPU: ≥ 2 cores, RAM: ≥ 2048 MB
5. Start the VM — installation is **fully automatic** (≈ 10–20 min)
6. The VM reboots and runs firstboot setup (≈ 5–10 min more)

> **No interaction needed** — boot it and walk away.

### What happens on first boot
1. Ubuntu installs unattended via `autoinstall` (cloud-init)
2. Machine reboots into the fresh install
3. `wosland-firstboot.service` runs: installs desktop, bot, VNC, web panel
4. Machine reboots one final time — fully ready

---

## ⚡ Method 2 — Proxmox LXC Container

> Run all commands **on the Proxmox host** as root.

```bash
cd wosland-x86

# Basic — DHCP, next available CT ID
sudo ./build-lxc.sh

# Custom CT ID, static IP
sudo ./build-lxc.sh --ctid 150
CT_IP="192.168.1.50/24" CT_GW="192.168.1.1" sudo ./build-lxc.sh --ctid 150

# Custom storage / RAM
CT_STORAGE=local CT_RAM=4096 CT_CORES=4 sudo ./build-lxc.sh
```

The script will:
1. Download the Ubuntu 24.04 LXC template automatically
2. Create and configure the container
3. Run full provisioning inside it (≈ 5–15 minutes)
4. Print the IP address and access URLs when done

### LXC environment variables

| Variable | Default | Description |
|---|---|---|
| `CTID` | auto | Proxmox container ID |
| `CT_STORAGE` | `local-lvm` | Proxmox storage pool |
| `CT_DISK_SIZE` | `20` | Disk size in GB |
| `CT_RAM` | `2048` | RAM in MB |
| `CT_CORES` | `2` | CPU cores |
| `CT_BRIDGE` | `vmbr0` | Proxmox network bridge |
| `CT_VLAN` | *(none)* | VLAN tag |
| `CT_IP` | `dhcp` | IP/CIDR or `dhcp` |
| `CT_GW` | *(none)* | Gateway for static IP |

---

## 🌐 Web Control Panel

Open `http://<machine-ip>:8080` in any browser.

- **Start / Stop / Restart** the wosbot service
- **Update the bot token** (auto-restarts the bot)
- **Live log viewer** — last 80 lines of journald output
- **Service status** at a glance

### API
```bash
curl http://<ip>:8080/api/status
curl http://<ip>:8080/api/logs?lines=200
```

---

## 🔑 Updating the Bot Token

### Web panel (easiest)
Go to `http://<ip>:8080` → paste token → Save

### SSH
```bash
ssh wosland@<ip>
echo "YOUR_TOKEN" > ~/bot/bot_token.txt
sudo systemctl restart wosbot
```

### Helper script (on the machine)
```bash
sudo /usr/local/bin/update-token.sh YOUR_TOKEN
```

---

## 🔄 Rebuilding with Updated Repo Links

Edit **only** `config.sh`:
```bash
nano config.sh
# Update BOT_MAIN_PY, BOT_INSTALL_PY, REPO_BASE, etc.

# Then rebuild:
sudo ./build-iso.sh       # for ISO
sudo ./build-lxc.sh       # for a new LXC container
```

---

## 🖥️ Desktop & VNC

The desktop (XFCE by default) runs on a **virtual framebuffer** (`:1`) accessible via VNC. This means it works equally well on bare metal, VMs, and headless LXC containers.

**Connect with any VNC client:**
- Host: `<machine-ip>:5900`
- Password: `W0sL@nd`

**Change the desktop in `config.sh`:**
```bash
DESKTOP="xfce"   # xfce | lxde | mate
```

---

## 🔐 Default Credentials

| Service | Username | Password |
|---|---|---|
| Linux / SSH | `wosland` | `W0sL@nd` |
| VNC | *(none)* | `W0sL@nd` |
| Web panel | *(no auth)* | — |

> Change after first login: `passwd`

---

## 🛠️ Service Management

```bash
sudo systemctl status wosbot
sudo systemctl restart wosbot
sudo journalctl -u wosbot -f

sudo systemctl status wosland-web
sudo systemctl status x11vnc
sudo systemctl status xvfb
```

---

## 📁 File Locations

| File | Path |
|---|---|
| Bot script | `/home/wosland/bot/main.py` |
| Bot token | `/home/wosland/bot/bot_token.txt` |
| Python venv | `/home/wosland/bot/venv/` |
| Wosbot service | `/etc/systemd/system/wosbot.service` |
| Web panel | `/opt/wosland-webserver/app.py` |
| Provisioning log | `/var/log/wosland-setup.log` |
| Wallpaper | `/usr/share/wallpapers/wosland/woslandOS.png` |

---

## 🐛 Troubleshooting

**ISO install stuck / not starting automatically**
- Check BIOS boot order — USB/DVD must be first
- Try switching between UEFI and Legacy boot in BIOS
- Proxmox VM: make sure the ISO is attached to the CDROM drive

**LXC provisioning failed midway**
```bash
# Re-run provisioning inside the container
pct exec <CTID> -- WOSLAND_REBOOT=0 /usr/local/bin/wosland-provision.sh
# Or check the log
pct exec <CTID> -- cat /var/log/wosland-setup.log
```

**VNC not connecting**
```bash
sudo systemctl restart xvfb x11vnc
sudo journalctl -u x11vnc -n 30
```

**Bot not starting**
```bash
sudo systemctl status wosbot
sudo journalctl -u wosbot -n 50
cat ~/bot/bot_token.txt  # must have a valid token
```

**Web panel not loading**
```bash
sudo systemctl status wosland-web
sudo journalctl -u wosland-web -n 30
# Check port is open
ss -tlnp | grep 8080
```
