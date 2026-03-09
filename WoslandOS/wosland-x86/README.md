# WoslandOS — x86 / Proxmox LXC

> For Raspberry Pi see [wosland-rpi/](../wosland-rpi/README.md) | Root overview: [README](../README.md)

Same bot, desktop, VNC, SSH, and web panel as the Pi image — but for x86-64 machines: old PCs, Proxmox VMs, and Proxmox LXC containers.

---

## What Gets Installed

| Component | Details |
|---|---|
| OS | Ubuntu Server 24.04 LTS (x86-64) |
| Desktop | XFCE4 (configurable: xfce / lxde / mate) |
| User | `wosland` / `W0sL@nd` |
| Hostname | `Wosland-os-server` |
| WOSBot | Python bot, systemd service `wosbot` |
| Web panel | Flask app on port **8080** |
| VNC | x11vnc on port **5900** via virtual framebuffer |
| SSH | OpenSSH on port **22** |
| Wallpaper | WoslandOS background set on the desktop |

---

## Choosing Your Install Method

| Method | Best for | Script |
|---|---|---|
| ISO | Old PC, bare metal, Proxmox VM, VirtualBox | `build-iso.sh` |
| LXC | Proxmox container (lightweight, no full VM) | `build-lxc.sh` |

---

## Method 1 — ISO (Bare Metal / VM)

### Build requirements

```bash
sudo apt install xorriso wget openssl p7zip-full
```

### Build the ISO

```bash
cd wosland-x86

# Optional: edit config.sh to change URLs, credentials, or desktop
nano config.sh

sudo ./build-iso.sh
# Output: ./output/wosland-os-x86-YYYYMMDD.iso
```

The Ubuntu version is **auto-detected** at build time — always picks the latest 24.04.x release. To force a fresh download:
```bash
sudo ./build-iso.sh --clean
```

### Flash to USB (bare metal)

```bash
sudo dd if=output/wosland-os-x86-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
Or use **Rufus** / **Ventoy** on Windows.

### Proxmox VM

1. Upload the ISO to Proxmox ISO storage
2. Create VM — recommended specs: 2+ cores, 2GB+ RAM, 20GB+ disk
3. Attach the ISO to the CDROM drive
4. Start the VM — installation is **fully automatic** (no interaction needed)
5. The VM installs Ubuntu, reboots, then runs first-boot setup (~15–20 min total)

### What happens automatically

1. Ubuntu installs unattended via autoinstall (cloud-init)
2. Machine reboots into fresh install
3. First-boot service installs desktop, bot, VNC, SSH, web panel
4. Machine reboots — fully ready

---

## Method 2 — Proxmox LXC

Run on your **Proxmox host** as root:

```bash
cd wosland-x86

# Basic — DHCP, auto container ID
sudo ./build-lxc.sh

# Custom container ID
sudo ./build-lxc.sh --ctid 150

# Static IP
CT_IP="192.168.1.50/24" CT_GW="192.168.1.1" sudo ./build-lxc.sh --ctid 150

# Custom resources
CT_STORAGE=local CT_RAM=4096 CT_CORES=4 sudo ./build-lxc.sh
```

The script downloads the Ubuntu 24.04 LXC template automatically, creates the container, and runs full provisioning inside it. IP and access URLs are printed when done.

### LXC environment variables

| Variable | Default | Description |
|---|---|---|
| `CTID` | auto | Proxmox container ID |
| `CT_STORAGE` | `local-lvm` | Proxmox storage pool |
| `CT_DISK_SIZE` | `20` | Disk size in GB |
| `CT_RAM` | `2048` | RAM in MB |
| `CT_CORES` | `2` | CPU cores |
| `CT_BRIDGE` | `vmbr0` | Network bridge |
| `CT_VLAN` | *(none)* | VLAN tag |
| `CT_IP` | `dhcp` | IP/CIDR or `dhcp` |
| `CT_GW` | *(none)* | Gateway (static IP only) |

---

## Web Control Panel

Open `http://<machine-ip>:8080` in any browser.

- Start / Stop / Restart the wosbot service
- Paste and save a new bot token (auto-restarts the service)
- Live log viewer
- Service status at a glance

**API:**
```bash
curl http://<ip>:8080/api/status
curl http://<ip>:8080/api/logs?lines=200
```

---

## Updating the Bot Token

**Web panel (easiest):** `http://<ip>:8080` → paste token → Save Token

**SSH:**
```bash
ssh wosland@<ip>
echo "YOUR_TOKEN" > ~/bot/bot_token.txt
sudo systemctl restart wosbot
```

**Helper script (run on the machine):**
```bash
sudo /usr/local/bin/update-token.sh YOUR_TOKEN
```

---

## Updating Repo Links

Edit only `config.sh`, then rebuild:

```bash
nano config.sh        # update BOT_MAIN_PY, BOT_INSTALL_PY, REPO_BASE, etc.
sudo ./build-iso.sh   # or build-lxc.sh
```

To change the desktop environment:
```bash
# In config.sh:
DESKTOP="xfce"   # xfce | lxde | mate
```

---

## Desktop & VNC

The desktop runs on a virtual framebuffer (`:1`) so it works equally on bare metal, VMs, and headless LXC containers. Connect with any VNC client:

- **Host:** `<machine-ip>:5900`
- **Password:** `W0sL@nd`

---

## Service Management

```bash
sudo systemctl status wosbot
sudo systemctl start | stop | restart wosbot
sudo journalctl -u wosbot -f

sudo systemctl status wosland-web
sudo systemctl status x11vnc
sudo systemctl status xvfb
```

---

## File Locations

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

## Default Credentials

| Service | Username | Password |
|---|---|---|
| Linux / SSH | `wosland` | `W0sL@nd` |
| VNC | *(none)* | `W0sL@nd` |
| Web panel | *(no auth)* | — |

---

## Troubleshooting

**ISO install not starting automatically**
- Check BIOS boot order — USB/DVD must be first
- Try toggling UEFI vs Legacy boot in BIOS
- Proxmox VM: confirm ISO is attached to CDROM drive

**LXC provisioning failed midway**
```bash
pct exec <CTID> -- WOSLAND_REBOOT=0 /usr/local/bin/wosland-provision.sh
# Or check the log:
pct exec <CTID> -- cat /var/log/wosland-setup.log
```

**build-iso.sh fails at extraction step**
```bash
sudo apt install p7zip-full
sudo ./build-iso.sh
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
cat ~/bot/bot_token.txt   # must contain a valid token
```

**Web panel not loading**
```bash
sudo systemctl status wosland-web
sudo journalctl -u wosland-web -n 30
ss -tlnp | grep 8080
```

---

## License

MIT — see [LICENSE](LICENSE)
