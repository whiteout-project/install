# WoslandOS — x86 / Proxmox

> For Raspberry Pi see [wosland-rpi/README.md](../wosland-rpi/README.md) | Back to [root README](../README.md)

Same bot stack as the Pi image — but for x86-64 machines. Choose between a fully unattended bootable ISO (bare metal, VMs) or a one-command Proxmox LXC container.

---

## System Requirements

### ISO — Bare Metal or Virtual Machine

| | Minimum | Recommended |
|---|---|---|
| **CPU** | 64-bit dual-core (x86-64) | Quad-core 2 GHz+ |
| **RAM** | 2 GB | 4 GB+ |
| **Disk** | 16 GB | 32 GB+ SSD |
| **Network** | Any wired NIC | Wired 100 Mbit+ |
| **Firmware** | Legacy BIOS or UEFI | UEFI |
| **Internet** | Required during first-boot setup | — |

### Proxmox LXC

| | Minimum | Recommended |
|---|---|---|
| **CPU cores** | 1 | 2 |
| **RAM** | 512 MB | 1–2 GB |
| **Disk** | 10 GB | 20 GB |
| **Proxmox version** | 7.x | 8.x |
| **LXC features** | `nesting=1` (set automatically) | — |
| **Internet** | Required during provisioning | — |

### Build Machine Requirements (ISO method only)

```bash
sudo apt install xorriso wget openssl p7zip-full
```

The ISO build must be run on a Linux machine. WSL2 on Windows is supported.

---

## What Gets Installed

| Component | Details |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS (x86-64), latest point release |
| **User account** | `wosland` / `W0sL@nd`, passwordless sudo |
| **Hostname** | `Wosland-os-server` |
| **Desktop** | XFCE4, autologin, WoslandOS wallpaper |
| **Bot (default)** | Whiteout Survival Python bot, systemd service `wosbot` |
| **Node.js** | v22 LTS (pre-installed for JS bot switching) |
| **Web panel** | Flask app, port **8080** |
| **VNC** | x11vnc, port **5900**, virtual framebuffer |
| **SSH** | OpenSSH, port **22** |
| **Desktop shortcut** | `WoslandOS Control Panel` opens web panel in browser |

---

## Choosing Your Install Method

| Method | Best for | Time | Script |
|---|---|---|---|
| **ISO** | Old PC, bare metal, Proxmox VM, VirtualBox | ~20 min | `build-iso.sh` |
| **LXC** | Proxmox container — lightweight, no full VM overhead | ~10 min | `build-lxc.sh` |

---

## Method 1 — ISO (Bare Metal / VM)

### Step 1 — Configure

```bash
cd wosland-x86
nano config.sh
```

Key values to review:

```bash
OS_PASSWORD="W0sL@nd"           # Change this!
DEFAULT_BOT="wos-py"            # wos-py | wos-js | kingshot
DESKTOP="xfce"                  # xfce | lxde | mate
UBUNTU_SERIES="24.04"           # auto-detects latest point release
```

### Step 2 — Build the ISO

```bash
sudo ./build-iso.sh
# Output: ./output/wosland-os-x86-YYYYMMDD.iso
```

The Ubuntu ISO is **auto-detected** at build time — always grabs the latest 24.04.x release. To force a fresh download:
```bash
sudo ./build-iso.sh --clean
```

**Expected build time:** 5–20 minutes depending on connection speed and whether the base ISO is cached.

### Step 3 — Flash / Load the ISO

**USB drive (bare metal — Linux/macOS):**
```bash
# Replace /dev/sdX with your USB drive — verify with lsblk first!
sudo dd if=output/wosland-os-x86-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

**USB drive (bare metal — Windows):**
Use [Rufus](https://rufus.ie/) — select the ISO, choose your USB drive, write in **DD mode**.

**Ventoy:**
Copy the `.iso` to a Ventoy drive and select it from the Ventoy boot menu.

**Proxmox VM:**
1. In Proxmox, go to **Local storage → ISO Images → Upload** and upload your `.iso`
2. Create a new VM:
   - OS: Linux (Ubuntu)
   - Disk: 20 GB+ (local-lvm or your storage pool)
   - RAM: 2048 MB+
   - CPU: 2 cores+
   - Network: VirtIO, bridge `vmbr0`
3. On the **CD/DVD** tab, select your uploaded ISO
4. **Start** the VM — installation is fully automatic, no interaction needed

### Step 4 — Automated Installation

Once booted from the ISO, the process is entirely hands-off:

1. Ubuntu autoinstall (cloud-init) partitions the disk and installs the base OS (~10 min)
2. System reboots into the fresh install
3. `wosland-firstboot.service` runs and installs everything — desktop, bot, VNC, SSH, web panel (~10 min)
4. System reboots again — fully ready

> Do **not** remove the ISO/USB until the machine has completed the second reboot.

### Step 5 — Access

| Service | Address | Credentials |
|---|---|---|
| **Web panel** | `http://<machine-ip>:8080` | No login |
| **SSH** | `ssh wosland@<machine-ip>` | Password: `W0sL@nd` |
| **VNC** | `<machine-ip>:5900` | Password: `W0sL@nd` |

---

## Method 2 — Proxmox LXC

Run these commands directly on your **Proxmox host** as root. No ISO building needed.

### Step 1 — Configure

```bash
cd wosland-x86
nano config.sh      # Review credentials and bot settings
```

### Step 2 — Create and Provision the Container

**Basic (DHCP, auto container ID):**
```bash
sudo ./build-lxc.sh
```

**Custom container ID:**
```bash
sudo ./build-lxc.sh --ctid 150
```

**Static IP:**
```bash
CT_IP="192.168.1.50/24" CT_GW="192.168.1.1" sudo ./build-lxc.sh --ctid 150
```

**Custom resources:**
```bash
CT_STORAGE=local CT_RAM=2048 CT_CORES=2 CT_DISK_SIZE=25 sudo ./build-lxc.sh
```

The script:
1. Downloads the Ubuntu 24.04 LXC template from Proxmox's repository (if not already cached)
2. Creates the container with `nesting=1` features enabled (required for systemd)
3. Starts the container and runs full provisioning inside it
4. Prints the IP address and access URLs when done

**Expected time:** 5–15 minutes.

### LXC Environment Variables

| Variable | Default | Description |
|---|---|---|
| `CTID` | auto (next available) | Proxmox container ID |
| `CT_STORAGE` | `local-lvm` | Proxmox storage pool name |
| `CT_DISK_SIZE` | `20` | Root disk size in GB |
| `CT_RAM` | `2048` | Memory in MB |
| `CT_CORES` | `2` | vCPU count |
| `CT_BRIDGE` | `vmbr0` | Network bridge |
| `CT_VLAN` | *(none)* | VLAN tag (optional) |
| `CT_IP` | `dhcp` | IP/CIDR or `dhcp` |
| `CT_GW` | *(none)* | Gateway (required for static IP) |

### Step 3 — Access

IP and URLs are printed at the end of provisioning. You can also find the IP with:
```bash
pct exec <CTID> -- hostname -I
```

| Service | Address | Credentials |
|---|---|---|
| **Web panel** | `http://<container-ip>:8080` | No login |
| **SSH** | `ssh wosland@<container-ip>` | Password: `W0sL@nd` |
| **VNC** | `<container-ip>:5900` | Password: `W0sL@nd` |

---

## Web Control Panel

Open `http://<machine-ip>:8080` in any browser.

| Feature | Description |
|---|---|
| **Service Control** | Start / Stop / Restart the bot. Live status indicator |
| **Bot Token** | Paste token → Save & Restart. Writes to the correct file for the active bot automatically |
| **Bot Selection** | Switch between Whiteout Survival (Python), Whiteout Survival (JS), and Kingshot. Two-step confirmation. Token carried over |
| **Desktop & GUI** | Toggle XFCE desktop autostart on/off (next reboot) |
| **Recent Logs** | Last 80 lines of bot journal output, refreshes every 15 s |

### Switching Bots

| Bot | Language | Token file |
|---|---|---|
| Whiteout Survival (Python) | Python 3 | `~/bot/bot_token.txt` |
| Whiteout Survival (JS) | Node.js 22 | `~/bot/src/.env` |
| Kingshot | Python 3 | `~/bot/bot_token.txt` |

Steps:
1. Select a different bot → **Switch Bot** button becomes active
2. Click **Switch Bot**
3. Confirm in warning dialog → **Continue**
4. Confirm in second dialog → **Yes, Switch Now**
5. Watch the live install log
6. Dashboard auto-refreshes when done

> Switching takes 3–10 minutes. The old bot directory is wiped and the new bot installed fresh.

---

## Updating the Bot Token

**Web panel (easiest):**
`http://<ip>:8080` → Bot Token card → paste → **Save & Restart**

**SSH:**
```bash
ssh wosland@<ip>
echo "YOUR_TOKEN_HERE" > ~/bot/bot_token.txt
sudo systemctl restart wosbot
```

> If using the JS bot, write to `~/bot/src/.env` instead:
> ```bash
> echo "TOKEN=YOUR_TOKEN_HERE" > ~/bot/src/.env
> ```

---

## Service Management (SSH)

```bash
# Bot
sudo systemctl status wosbot
sudo systemctl start | stop | restart wosbot
sudo journalctl -u wosbot -f
sudo journalctl -u wosbot -n 100

# Web panel
sudo systemctl status wosland-web
sudo journalctl -u wosland-web -n 50

# VNC
sudo systemctl status xvfb x11vnc
sudo systemctl restart xvfb x11vnc

# SSH
sudo systemctl status ssh
```

---

## Desktop GUI

XFCE4 is enabled by default on bare-metal / VM installs. It is **disabled** by default in LXC (no display manager in containers).

Toggle from the web panel: **Desktop & GUI card** → toggle → takes effect on next reboot.

Connect via VNC:
- **Host:** `<machine-ip>:5900`
- **Password:** `W0sL@nd`

Recommended VNC clients: [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/), [TigerVNC](https://tigervnc.org/), Remmina (Linux)

A **WoslandOS Control Panel** shortcut sits on the XFCE desktop and opens the web panel.

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
| Bot switcher | `/usr/local/bin/wosland-switch-bot.sh` |
| Provisioning log | `/var/log/wosland-setup.log` |
| Bot switch log | `/var/log/wosland-switch.log` |
| Wallpaper | `/usr/share/wallpapers/wosland/woslandOS.png` |
| GUI flag | `/etc/wosland/gui_enabled` (present = GUI on) |

---

## Default Credentials

| Service | Username | Password |
|---|---|---|
| Linux / SSH | `wosland` | `W0sL@nd` |
| VNC | *(none)* | `W0sL@nd` |
| Web panel | *(no auth)* | — |

> Change the password: `passwd`

---

## Troubleshooting

**ISO install not starting automatically (bare metal)**
- Confirm BIOS boot order — USB/DVD must be before the hard drive
- Try toggling UEFI ↔ Legacy in BIOS settings
- On Proxmox VM: confirm the ISO is attached to CDROM and VM is set to boot from it

**ISO build fails at extraction step**
```bash
sudo apt install p7zip-full xorriso
sudo ./build-iso.sh
```

**LXC container created but provisioning failed midway**
```bash
# Check the log
pct exec <CTID> -- cat /var/log/wosland-setup.log

# Re-run provisioning (safe to re-run)
pct exec <CTID> -- bash -c "WOSLAND_REBOOT=0 /usr/local/bin/wosland-provision.sh"
```

**LXC "no space left on device" during provisioning**
```bash
# Option 1: destroy and recreate with more disk
pct destroy <CTID>
CT_DISK_SIZE=40 sudo ./build-lxc.sh --ctid <CTID>

# Option 2: resize existing container
pct resize <CTID> rootfs 40G
pct exec <CTID> -- bash -c "WOSLAND_REBOOT=0 /usr/local/bin/wosland-provision.sh"
```

**Web panel not loading at port 8080**
```bash
sudo systemctl status wosland-web
sudo journalctl -u wosland-web -n 50
ss -tlnp | grep 8080
```

**Bot not starting**
```bash
sudo systemctl status wosbot
sudo journalctl -u wosbot -n 50
cat ~/bot/bot_token.txt     # must contain a valid token
cat ~/bot/.bot_type         # check active bot type
```

**Bot switch failed / bot in broken state**
```bash
sudo cat /var/log/wosland-switch.log

# Re-run switch for a specific bot
sudo /usr/local/bin/wosland-switch-bot.sh wos-py
sudo /usr/local/bin/wosland-switch-bot.sh wos-js
sudo /usr/local/bin/wosland-switch-bot.sh kingshot
```

**VNC not connecting**
```bash
sudo systemctl restart xvfb
sleep 3
sudo systemctl restart x11vnc
sudo journalctl -u x11vnc -n 30
```

**LXC — apparmor rsyslog denied errors in journal**
These are harmless noise from rsyslog trying to use the systemd journal socket. rsyslog is masked during provisioning to suppress this. If they reappear:
```bash
sudo systemctl mask rsyslog
```

---

## License

MIT — see [LICENSE](LICENSE)
