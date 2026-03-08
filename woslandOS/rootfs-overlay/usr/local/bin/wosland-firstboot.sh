#!/usr/bin/env bash
# ============================================================
# WoslandOS — First Boot Setup Script
# This script runs once on first boot of the Pi.
# Generated values are sourced from config.sh at build time.
# ============================================================
set -euo pipefail

LOG="/var/log/wosland-setup.log"
exec > >(tee -a "$LOG") 2>&1

echo "========================================="
echo " WoslandOS First-Boot Setup Starting"
echo " $(date)"
echo "========================================="

# ── Injected by build process ────────────────────────────────
OS_USERNAME="@@OS_USERNAME@@"
OS_PASSWORD="@@OS_PASSWORD@@"
OS_HOSTNAME="@@OS_HOSTNAME@@"
BOT_MAIN_PY="@@BOT_MAIN_PY@@"
BOT_INSTALL_PY="@@BOT_INSTALL_PY@@"
BACKGROUND_IMAGE_URL="@@BACKGROUND_IMAGE_URL@@"
BOT_DIR="@@BOT_DIR@@"
VENV_DIR="@@VENV_DIR@@"
SERVICE_NAME="@@SERVICE_NAME@@"
TOKEN_FILE="@@TOKEN_FILE@@"
WEBSERVER_DIR="@@WEBSERVER_DIR@@"
WEBSERVER_PORT="@@WEBSERVER_PORT@@"

# ── 1. Hostname ───────────────────────────────────────────────
echo "[1/10] Setting hostname..."
hostnamectl set-hostname "$OS_HOSTNAME"
sed -i "s/127.0.1.1.*/127.0.1.1\t${OS_HOSTNAME}/" /etc/hosts || \
  echo "127.0.1.1	${OS_HOSTNAME}" >> /etc/hosts

# ── 2. User account ───────────────────────────────────────────
echo "[2/10] Creating user ${OS_USERNAME}..."
if ! id "$OS_USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input "$OS_USERNAME"
fi
echo "${OS_USERNAME}:${OS_PASSWORD}" | chpasswd
# Disable default ubuntu user if it exists
if id ubuntu &>/dev/null; then
  usermod -L ubuntu || true
fi

# ── 3. System update ──────────────────────────────────────────
echo "[3/10] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# ── 4. Core dependencies ──────────────────────────────────────
echo "[4/10] Installing dependencies..."
apt-get install -y -qq \
  python3 python3-full python3-venv python3-pip wget curl git \
  openssh-server \
  x11vnc xvfb \
  feh \
  jq \
  python3-flask \
  gunicorn \
  net-tools

# ── 5. Bot installation ───────────────────────────────────────
echo "[5/10] Installing WOSBot..."
mkdir -p "$BOT_DIR"
chown -R "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"

cd "$BOT_DIR"
wget -q -O main.py "$BOT_MAIN_PY"
wget -q -O install.py "$BOT_INSTALL_PY"

# Create venv as the bot user
sudo -u "$OS_USERNAME" python3 -m venv "$VENV_DIR"
sudo -u "$OS_USERNAME" "$VENV_DIR/bin/pip" install --quiet --upgrade pip

# Run install.py inside venv
cd "$BOT_DIR"
sudo -u "$OS_USERNAME" "$VENV_DIR/bin/python3" install.py || true
rm -f install.py

# Create empty token file if not already created by install.py
if [ ! -f "$TOKEN_FILE" ]; then
  echo "" > "$TOKEN_FILE"
  chown "${OS_USERNAME}:${OS_USERNAME}" "$TOKEN_FILE"
  chmod 640 "$TOKEN_FILE"
fi

# ── 6. Wosbot systemd service ─────────────────────────────────
echo "[6/10] Installing wosbot service..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=WOSBot
After=network.target

[Service]
ExecStart=${VENV_DIR}/bin/python3 ${BOT_DIR}/main.py --autoupdate
WorkingDirectory=${BOT_DIR}
Restart=always
RestartSec=5
User=${OS_USERNAME}
EnvironmentFile=-${BOT_DIR}/bot.env

[Install]
WantedBy=multi-user.target
EOF

# ── 7. Background image ───────────────────────────────────────
echo "[7/10] Setting up background image..."
WALLPAPER_DIR="/usr/share/wallpapers/wosland"
mkdir -p "$WALLPAPER_DIR"
wget -q -O "${WALLPAPER_DIR}/woslandOS.png" "$BACKGROUND_IMAGE_URL" || true

# Set background for any graphical session via feh
cat > "/home/${OS_USERNAME}/.fehbg" <<'FEHEOF'
#!/bin/bash
feh --bg-scale /usr/share/wallpapers/wosland/woslandOS.png
FEHEOF
chmod +x "/home/${OS_USERNAME}/.fehbg"
echo '@/home/'"${OS_USERNAME}"'/.fehbg' >> "/home/${OS_USERNAME}/.config/openbox/autostart" 2>/dev/null || true

# ── 8. SSH hardening ──────────────────────────────────────────
echo "[8/10] Configuring SSH..."
systemctl enable ssh
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh || true

# ── 9. VNC setup ──────────────────────────────────────────────
echo "[9/10] Setting up VNC..."
# Create a persistent virtual display + x11vnc service
VNC_PASS=$(echo "$OS_PASSWORD" | tr -d '\n')

mkdir -p "/home/${OS_USERNAME}/.vnc"
x11vnc -storepasswd "$VNC_PASS" "/home/${OS_USERNAME}/.vnc/passwd" 2>/dev/null || \
  echo "$VNC_PASS" > "/home/${OS_USERNAME}/.vnc/passwd-plain"
chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.vnc"

cat > /etc/systemd/system/xvfb.service <<'XVFBEOF'
[Unit]
Description=Virtual Framebuffer X Server
After=network.target

[Service]
ExecStart=/usr/bin/Xvfb :1 -screen 0 1920x1080x24
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
XVFBEOF

cat > /etc/systemd/system/x11vnc.service <<VNCEOF
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
VNCEOF

systemctl daemon-reload
systemctl enable xvfb x11vnc wosbot

# ── 10. Web control panel ─────────────────────────────────────
echo "[10/10] Installing web control panel..."
mkdir -p "$WEBSERVER_DIR"
# The web server files are copied from the image overlay
# (already placed at $WEBSERVER_DIR by the build process)
# Install as a service
cat > /etc/systemd/system/wosland-web.service <<WEBEOF
[Unit]
Description=WoslandOS Web Control Panel
After=network.target

[Service]
ExecStart=/usr/bin/python3 ${WEBSERVER_DIR}/app.py
WorkingDirectory=${WEBSERVER_DIR}
Restart=always
RestartSec=5
User=root
Environment=WOSLAND_USER=${OS_USERNAME}
Environment=BOT_DIR=${BOT_DIR}
Environment=TOKEN_FILE=${TOKEN_FILE}
Environment=SERVICE_NAME=${SERVICE_NAME}
Environment=PORT=${WEBSERVER_PORT}

[Install]
WantedBy=multi-user.target
WEBEOF

systemctl daemon-reload
systemctl enable wosland-web

# ── Auto-disable this setup service ───────────────────────────
echo "Setup complete. Disabling first-boot service..."
systemctl disable wosland-firstboot.service || true
rm -f /etc/systemd/system/wosland-firstboot.service

echo "========================================="
echo " WoslandOS First-Boot Setup COMPLETE"
echo " Rebooting in 5 seconds..."
echo "========================================="
sleep 5
reboot
