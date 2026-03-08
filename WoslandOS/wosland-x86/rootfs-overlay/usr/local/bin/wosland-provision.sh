#!/usr/bin/env bash
# ============================================================
# WoslandOS x86/LXC — Provisioning Script
# Works both as a first-boot service (ISO install) and as a
# script run directly inside an LXC container (Proxmox).
#
# Placeholders (@@...@@) are substituted by the build scripts.
# ============================================================
set -euo pipefail

LOG="/var/log/wosland-setup.log"
exec > >(tee -a "$LOG") 2>&1

echo "========================================="
echo " WoslandOS Provisioning Starting"
echo " $(date)"
echo "========================================="

# ── Injected config ──────────────────────────────────────────
OS_USERNAME="@@OS_USERNAME@@"
OS_PASSWORD="@@OS_PASSWORD@@"
OS_HOSTNAME="@@OS_HOSTNAME@@"
BOT_MAIN_PY="@@BOT_MAIN_PY@@"
BOT_INSTALL_PY="@@BOT_INSTALL_PY@@"
BACKGROUND_IMAGE_URL="@@BACKGROUND_IMAGE_URL@@"
DESKTOP="@@DESKTOP@@"
BOT_DIR="@@BOT_DIR@@"
VENV_DIR="@@VENV_DIR@@"
SERVICE_NAME="@@SERVICE_NAME@@"
TOKEN_FILE="@@TOKEN_FILE@@"
WEBSERVER_DIR="@@WEBSERVER_DIR@@"
WEBSERVER_PORT="@@WEBSERVER_PORT@@"

# Detect if we're inside an LXC (no systemd-boot, different init)
IS_LXC=0
if grep -q "container=lxc" /proc/1/environ 2>/dev/null || \
   [ -f /run/systemd/container ] || \
   systemd-detect-virt --container &>/dev/null 2>&1; then
  IS_LXC=1
  echo "[INFO] Running inside LXC container"
fi

export DEBIAN_FRONTEND=noninteractive

# ── 1. Hostname ──────────────────────────────────────────────
echo "[1/11] Setting hostname..."
hostnamectl set-hostname "$OS_HOSTNAME" 2>/dev/null || \
  echo "$OS_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t${OS_HOSTNAME}/" /etc/hosts 2>/dev/null || \
  echo "127.0.1.1	${OS_HOSTNAME}" >> /etc/hosts

# ── 2. User account ──────────────────────────────────────────
echo "[2/11] Creating user ${OS_USERNAME}..."
if ! id "$OS_USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash -G sudo,adm "$OS_USERNAME"
fi
echo "${OS_USERNAME}:${OS_PASSWORD}" | chpasswd
# Allow sudo without password for this user (optional — remove if you want strict)
echo "${OS_USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${OS_USERNAME}"
chmod 440 "/etc/sudoers.d/${OS_USERNAME}"

# ── 3. System update ─────────────────────────────────────────
echo "[3/11] Updating system..."
apt-get update -qq
apt-get upgrade -y -qq --no-install-recommends

# ── 4. Core packages ─────────────────────────────────────────
echo "[4/11] Installing core packages..."
apt-get install -y -qq --no-install-recommends \
  python3 python3-full python3-venv python3-pip \
  wget curl git ca-certificates \
  openssh-server \
  python3-flask \
  feh \
  jq \
  net-tools \
  unzip

# ── 5. Desktop environment ───────────────────────────────────
echo "[5/11] Installing desktop (${DESKTOP})..."

if [ "$IS_LXC" -eq 1 ]; then
  # LXC: install desktop + x11vnc for remote access (no physical display)
  case "$DESKTOP" in
    xfce) apt-get install -y -qq --no-install-recommends \
            xfce4 xfce4-terminal xfce4-session dbus-x11 ;;
    lxde) apt-get install -y -qq --no-install-recommends \
            lxde lxde-core lxsession dbus-x11 ;;
    mate) apt-get install -y -qq --no-install-recommends \
            mate-desktop-environment-core dbus-x11 ;;
    *)    apt-get install -y -qq --no-install-recommends \
            xfce4 xfce4-terminal xfce4-session dbus-x11 ;;
  esac
  apt-get install -y -qq x11vnc xvfb

else
  # Bare-metal / VM: full desktop with display manager
  case "$DESKTOP" in
    xfce) apt-get install -y -qq --no-install-recommends \
            xfce4 xfce4-terminal xfce4-session lightdm lightdm-gtk-greeter ;;
    lxde) apt-get install -y -qq --no-install-recommends \
            lxde lightdm ;;
    mate) apt-get install -y -qq --no-install-recommends \
            mate-desktop-environment lightdm ;;
    *)    apt-get install -y -qq --no-install-recommends \
            xfce4 xfce4-terminal xfce4-session lightdm lightdm-gtk-greeter ;;
  esac
  systemctl enable lightdm || true

  # Auto-login for the wosland user
  mkdir -p /etc/lightdm/lightdm.conf.d
  cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=${OS_USERNAME}
autologin-user-timeout=0
user-session=${DESKTOP}
EOF
fi

# ── 6. Background image ──────────────────────────────────────
echo "[6/11] Setting up wallpaper..."
WALLPAPER_DIR="/usr/share/wallpapers/wosland"
mkdir -p "$WALLPAPER_DIR"
wget -q -O "${WALLPAPER_DIR}/woslandOS.png" "$BACKGROUND_IMAGE_URL" || \
  echo "[WARN] Could not download wallpaper — check URL in config.sh"

# feh-based wallpaper setter (works across all WMs)
mkdir -p "/home/${OS_USERNAME}/.config/autostart"
cat > "/home/${OS_USERNAME}/.config/autostart/wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Set Wallpaper
Exec=feh --bg-scale /usr/share/wallpapers/wosland/woslandOS.png
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.config"

# XFCE specific wallpaper via xfconf (applied after login)
if [ "$DESKTOP" = "xfce" ]; then
  mkdir -p "/home/${OS_USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml"
  cat > "/home/${OS_USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/wallpapers/wosland/woslandOS.png"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
  chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.config/xfce4"
fi

# ── 7. Bot installation ──────────────────────────────────────
echo "[7/11] Installing WOSBot..."
mkdir -p "$BOT_DIR"
chown -R "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"
cd "$BOT_DIR"

wget -q -O main.py "$BOT_MAIN_PY"
wget -q -O install.py "$BOT_INSTALL_PY"

sudo -u "$OS_USERNAME" python3 -m venv "$VENV_DIR"
sudo -u "$OS_USERNAME" "$VENV_DIR/bin/pip" install --quiet --upgrade pip

cd "$BOT_DIR"
sudo -u "$OS_USERNAME" "$VENV_DIR/bin/python3" install.py || true
rm -f install.py

if [ ! -f "$TOKEN_FILE" ]; then
  echo "" > "$TOKEN_FILE"
  chown "${OS_USERNAME}:${OS_USERNAME}" "$TOKEN_FILE"
  chmod 640 "$TOKEN_FILE"
fi

# ── 8. Wosbot systemd service ────────────────────────────────
echo "[8/11] Installing wosbot service..."
cat > /etc/systemd/system/wosbot.service <<EOF
[Unit]
Description=WOSBot
After=network.target

[Service]
ExecStart=${VENV_DIR}/bin/python3 ${BOT_DIR}/main.py --autoupdate
WorkingDirectory=${BOT_DIR}
Restart=always
RestartSec=5
User=${OS_USERNAME}

[Install]
WantedBy=multi-user.target
EOF

# ── 9. SSH ───────────────────────────────────────────────────
echo "[9/11] Configuring SSH..."
systemctl enable ssh || systemctl enable openssh-server || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# ── 10. VNC (always installed for headless/LXC remote access) ─
echo "[10/11] Setting up VNC..."
mkdir -p "/home/${OS_USERNAME}/.vnc"
x11vnc -storepasswd "$OS_PASSWORD" "/home/${OS_USERNAME}/.vnc/passwd" 2>/dev/null || true
chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.vnc"

# Virtual framebuffer (needed in LXC; harmless on bare metal)
cat > /etc/systemd/system/xvfb.service <<'EOF'
[Unit]
Description=Virtual Framebuffer
After=network.target

[Service]
ExecStart=/usr/bin/Xvfb :1 -screen 0 1920x1080x24
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/x11vnc.service <<EOF
[Unit]
Description=x11vnc VNC Server
After=xvfb.service
Requires=xvfb.service

[Service]
ExecStart=/usr/bin/x11vnc -display :1 -rfbauth /home/${OS_USERNAME}/.vnc/passwd -rfbport 5900 -forever -shared -noxdamage
Restart=always
RestartSec=3
User=${OS_USERNAME}

[Install]
WantedBy=multi-user.target
EOF

# ── 11. Web control panel ────────────────────────────────────
echo "[11/11] Installing web control panel..."
mkdir -p "$WEBSERVER_DIR"
# app.py is already in place from the overlay / LXC provision copy
cat > /etc/systemd/system/wosland-web.service <<EOF
[Unit]
Description=WoslandOS Web Control Panel
After=network.target

[Service]
ExecStart=/usr/bin/python3 ${WEBSERVER_DIR}/app.py
WorkingDirectory=${WEBSERVER_DIR}
Restart=always
RestartSec=5
User=root
Environment=SERVICE_NAME=${SERVICE_NAME}
Environment=BOT_DIR=${BOT_DIR}
Environment=TOKEN_FILE=${TOKEN_FILE}
Environment=PORT=${WEBSERVER_PORT}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wosbot xvfb x11vnc wosland-web ssh || true

# ── Disable self (ISO firstboot) if present ──────────────────
systemctl disable wosland-firstboot.service 2>/dev/null || true
rm -f /etc/systemd/system/wosland-firstboot.service

echo "========================================="
echo " WoslandOS Provisioning COMPLETE"
echo " $(date)"
echo "========================================="
echo " SSH  : port 22  (user: ${OS_USERNAME})"
echo " VNC  : port 5900"
echo " Web  : port ${WEBSERVER_PORT}"
echo "========================================="

# Reboot only when running as a first-boot service (not in LXC direct mode)
if [ "${WOSLAND_REBOOT:-1}" = "1" ] && [ "$IS_LXC" -eq 0 ]; then
  echo "Rebooting in 5 seconds..."
  sleep 5
  reboot
fi
