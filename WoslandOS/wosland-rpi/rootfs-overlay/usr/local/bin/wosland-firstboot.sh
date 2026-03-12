#!/usr/bin/env bash
# ============================================================
# WoslandOS Raspberry Pi -- First Boot Setup Script
# ============================================================
set -euo pipefail
LOG="/var/log/wosland-setup.log"
exec > >(tee -a "$LOG") 2>&1

echo "========================================="
echo " WoslandOS First-Boot Setup Starting"
echo " $(date)"
echo "========================================="

OS_USERNAME="@@OS_USERNAME@@"
OS_PASSWORD="@@OS_PASSWORD@@"
OS_HOSTNAME="@@OS_HOSTNAME@@"
BOT_MAIN_PY="@@BOT_MAIN_PY@@"
BOT_INSTALL_PY="@@BOT_INSTALL_PY@@"
BOT_JS_REPO="@@BOT_JS_REPO@@"
BOT_JS_BRANCH="@@BOT_JS_BRANCH@@"
BOT_KINGSHOT_REPO="@@BOT_KINGSHOT_REPO@@"
BOT_KINGSHOT_BRANCH="@@BOT_KINGSHOT_BRANCH@@"
BACKGROUND_IMAGE_URL="@@BACKGROUND_IMAGE_URL@@"
BOT_DIR="@@BOT_DIR@@"
VENV_DIR="${BOT_DIR}/venv"
SERVICE_NAME="@@SERVICE_NAME@@"
SERVICE_FILE="@@SERVICE_FILE@@"
TOKEN_FILE="@@TOKEN_FILE@@"
WEBSERVER_DIR="@@WEBSERVER_DIR@@"
WEBSERVER_PORT="@@WEBSERVER_PORT@@"
DEFAULT_BOT="@@DEFAULT_BOT@@"

export DEBIAN_FRONTEND=noninteractive

# -- 1. Hostname
echo "[1/13] Setting hostname..."
hostnamectl set-hostname "$OS_HOSTNAME"
sed -i "s/127.0.1.1.*/127.0.1.1\t${OS_HOSTNAME}/" /etc/hosts 2>/dev/null || \
  echo "127.0.1.1	${OS_HOSTNAME}" >> /etc/hosts

# -- 2. User
echo "[2/13] Creating user ${OS_USERNAME}..."
if ! id "$OS_USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input "$OS_USERNAME"
fi
echo "${OS_USERNAME}:${OS_PASSWORD}" | chpasswd
if id ubuntu &>/dev/null; then usermod -L ubuntu || true; fi

# -- 3. System update
echo "[3/13] Updating system..."
apt-get update -qq
apt-get upgrade -y -qq

# -- 4. Core packages
echo "[4/13] Installing packages..."
apt-get install -y -qq \
  python3 python3-full python3-venv python3-pip wget curl git \
  openssh-server x11vnc xvfb feh python3-flask jq net-tools \
  xdotool ca-certificates unzip

# -- 5. Node.js 22
echo "[5/13] Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
apt-get install -y -qq nodejs

# -- 6. Desktop (XFCE)
echo "[6/13] Installing desktop..."
apt-get install -y -qq --no-install-recommends \
  xfce4 xfce4-terminal xfce4-session lightdm lightdm-gtk-greeter
systemctl enable lightdm || true
systemctl set-default graphical.target || true
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=${OS_USERNAME}
autologin-user-timeout=0
user-session=xfce
EOF

# -- 7. Wallpaper
echo "[7/13] Setting up wallpaper..."
WALL_DIR="/usr/share/wallpapers/wosland"
mkdir -p "$WALL_DIR"
wget -q -O "${WALL_DIR}/woslandOS.png" "$BACKGROUND_IMAGE_URL" || true

mkdir -p "/home/${OS_USERNAME}/.config/autostart"
cat > "/home/${OS_USERNAME}/.config/autostart/wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Set Wallpaper
Exec=feh --bg-scale /usr/share/wallpapers/wosland/woslandOS.png
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

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
chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.config"

# -- 8. Desktop shortcut for web panel
echo "[8/13] Creating desktop shortcut..."
DESK_DIR="/home/${OS_USERNAME}/Desktop"
mkdir -p "$DESK_DIR"
cat > "${DESK_DIR}/WoslandOS-Panel.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WoslandOS Control Panel
Comment=Open the WoslandOS web control panel
Exec=xdg-open http://localhost:${WEBSERVER_PORT}
Icon=applications-internet
Terminal=false
Categories=Network;
EOF
chmod +x "${DESK_DIR}/WoslandOS-Panel.desktop"
chown -R "${OS_USERNAME}:${OS_USERNAME}" "$DESK_DIR"

# -- 9. Bot installation
echo "[9/13] Installing WOSBot (${DEFAULT_BOT})..."
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"
wget -q -O main.py "$BOT_MAIN_PY"
wget -q -O install.py "$BOT_INSTALL_PY"
chown -R "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"
chmod 755 "$BOT_DIR"
sudo -u "$OS_USERNAME" python3 -m venv "$VENV_DIR"
sudo -u "$OS_USERNAME" "$VENV_DIR/bin/pip" install --quiet --upgrade pip
sudo -u "$OS_USERNAME" "$VENV_DIR/bin/python3" install.py || true
rm -f install.py
chown -R "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"
chmod 755 "$BOT_DIR"
if [ ! -f "$TOKEN_FILE" ]; then echo "" > "$TOKEN_FILE"; fi
chown root:root "$TOKEN_FILE"
chmod 644 "$TOKEN_FILE"
echo "$DEFAULT_BOT" > "${BOT_DIR}/.bot_type"
chown "${OS_USERNAME}:${OS_USERNAME}" "${BOT_DIR}/.bot_type"

# -- 10. Wosbot service
echo "[10/13] Installing wosbot service..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=WOSBot (Whiteout Survival - Python)
After=network.target
[Service]
ExecStart=${VENV_DIR}/bin/python3 ${BOT_DIR}/main.py --autoupdate
WorkingDirectory=${BOT_DIR}
Restart=always
RestartSec=5
User=${OS_USERNAME}
Environment="OMP_NUM_THREADS=1"
Environment="ONNXRUNTIME_NTHREADS=1"
[Install]
WantedBy=multi-user.target
EOF

# -- 11. SSH
echo "[11/13] Configuring SSH..."
systemctl enable ssh
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# -- 12. VNC
echo "[12/13] Setting up VNC..."
mkdir -p "/home/${OS_USERNAME}/.vnc"
x11vnc -storepasswd "$OS_PASSWORD" "/home/${OS_USERNAME}/.vnc/passwd" 2>/dev/null || true
chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.vnc"

cat > /etc/systemd/system/xvfb.service <<'EOF'
[Unit]
Description=Virtual Framebuffer X Server
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

# -- 13. Web control panel & switch-bot script
echo "[13/13] Installing web control panel..."
mkdir -p "$WEBSERVER_DIR"
chown root:root "$WEBSERVER_DIR"
chmod 755 "$WEBSERVER_DIR"
chown root:root "${WEBSERVER_DIR}/app.py"
chmod 755 "${WEBSERVER_DIR}/app.py"

# Ensure token has correct final permissions
chown root:root "$TOKEN_FILE"
chmod 644 "$TOKEN_FILE"

# Substitute and lock down switch-bot script
SWITCH_SRC="/usr/local/bin/wosland-switch-bot.sh"
sed -i \
  -e "s|@@OS_USERNAME@@|${OS_USERNAME}|g" \
  -e "s|@@BOT_DIR@@|${BOT_DIR}|g" \
  -e "s|@@SERVICE_NAME@@|${SERVICE_NAME}|g" \
  -e "s|@@TOKEN_FILE@@|${TOKEN_FILE}|g" \
  -e "s|@@BOT_MAIN_PY@@|${BOT_MAIN_PY}|g" \
  -e "s|@@BOT_INSTALL_PY@@|${BOT_INSTALL_PY}|g" \
  -e "s|@@BOT_JS_REPO@@|${BOT_JS_REPO}|g" \
  -e "s|@@BOT_JS_BRANCH@@|${BOT_JS_BRANCH}|g" \
  -e "s|@@BOT_KINGSHOT_REPO@@|${BOT_KINGSHOT_REPO}|g" \
  -e "s|@@BOT_KINGSHOT_BRANCH@@|${BOT_KINGSHOT_BRANCH}|g" \
  "$SWITCH_SRC"
chown root:root "$SWITCH_SRC"
chmod 755 "$SWITCH_SRC"

mkdir -p /etc/wosland
touch /etc/wosland/gui_enabled  # GUI enabled by default on Pi

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
Environment=OS_USERNAME=${OS_USERNAME}
Environment=BOT_DIR=${BOT_DIR}
Environment=TOKEN_FILE=${TOKEN_FILE}
Environment=SERVICE_NAME=${SERVICE_NAME}
Environment=PORT=${WEBSERVER_PORT}
[Install]
WantedBy=multi-user.target
WEBEOF

systemctl daemon-reload
for svc in wosbot xvfb x11vnc wosland-web ssh; do
  systemctl enable "$svc" 2>/dev/null || true
done

systemctl disable wosland-firstboot.service 2>/dev/null || true
rm -f /etc/systemd/system/wosland-firstboot.service

echo "========================================="
echo " WoslandOS First-Boot Setup COMPLETE"
echo " $(date)"
echo "========================================="
echo " SSH : port 22  (user: ${OS_USERNAME})"
echo " VNC : port 5900"
echo " Web : http://<pi-ip>:${WEBSERVER_PORT}"
echo "========================================="
sleep 5
reboot