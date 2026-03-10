#!/usr/bin/env bash
# ============================================================
# WoslandOS x86/LXC -- Provisioning Script
# ============================================================
set -euo pipefail

LOG="/var/log/wosland-setup.log"
exec > >(tee -a "$LOG") 2>&1

echo "========================================="
echo " WoslandOS Provisioning Starting"
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
DESKTOP="@@DESKTOP@@"
BOT_DIR="@@BOT_DIR@@"
VENV_DIR="${BOT_DIR}/venv"
SERVICE_NAME="@@SERVICE_NAME@@"
TOKEN_FILE="@@TOKEN_FILE@@"
WEBSERVER_DIR="@@WEBSERVER_DIR@@"
WEBSERVER_PORT="@@WEBSERVER_PORT@@"
DEFAULT_BOT="@@DEFAULT_BOT@@"

IS_LXC=0
if grep -q "container=lxc" /proc/1/environ 2>/dev/null || \
   systemd-detect-virt --container &>/dev/null 2>&1; then
  IS_LXC=1; echo "[INFO] Running inside LXC container"
fi

export DEBIAN_FRONTEND=noninteractive

# -- 1. Hostname
echo "[1/13] Setting hostname..."
hostnamectl set-hostname "$OS_HOSTNAME" 2>/dev/null || echo "$OS_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t${OS_HOSTNAME}/" /etc/hosts 2>/dev/null || \
  echo "127.0.1.1	${OS_HOSTNAME}" >> /etc/hosts

# -- 2. User
echo "[2/13] Creating user ${OS_USERNAME}..."
if ! id "$OS_USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash -G sudo,adm "$OS_USERNAME"
fi
echo "${OS_USERNAME}:${OS_PASSWORD}" | chpasswd
echo "${OS_USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${OS_USERNAME}"
chmod 440 "/etc/sudoers.d/${OS_USERNAME}"

# -- 3. System update
echo "[3/13] Updating system..."
apt-get update -qq
apt-get upgrade -y -qq --no-install-recommends

# -- 4. Core packages
echo "[4/13] Installing core packages..."
apt-get install -y -qq --no-install-recommends \
  python3 python3-full python3-venv python3-pip \
  wget curl git ca-certificates \
  openssh-server \
  python3-flask \
  feh jq net-tools unzip xdotool

# -- 5. Node.js 22
echo "[5/13] Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
apt-get install -y -qq nodejs

# -- 6. Desktop
echo "[6/13] Installing desktop (${DESKTOP})..."
if [ "$IS_LXC" -eq 1 ]; then
  apt-get install -y -qq --no-install-recommends xfce4 xfce4-terminal xfce4-session dbus-x11 x11vnc xvfb
else
  apt-get install -y -qq --no-install-recommends xfce4 xfce4-terminal xfce4-session lightdm lightdm-gtk-greeter x11vnc xvfb
  systemctl enable lightdm || true
  systemctl set-default graphical.target || true
  mkdir -p /etc/lightdm/lightdm.conf.d
  cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=${OS_USERNAME}
autologin-user-timeout=0
user-session=${DESKTOP}
EOF
fi

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
chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.config"

# XFCE wallpaper
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

# -- 8. Desktop shortcut for web panel
echo "[8/13] Creating desktop shortcut..."
DESKTOP_DIR="/home/${OS_USERNAME}/Desktop"
mkdir -p "$DESKTOP_DIR"
cat > "${DESKTOP_DIR}/WoslandOS-Panel.desktop" <<EOF
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
chmod +x "${DESKTOP_DIR}/WoslandOS-Panel.desktop"
chown -R "${OS_USERNAME}:${OS_USERNAME}" "$DESKTOP_DIR"

# -- 9. Bot installation (default: wos-py)
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
chown "${OS_USERNAME}:${OS_USERNAME}" "$TOKEN_FILE"
chmod 640 "$TOKEN_FILE"

# Record active bot type
echo "$DEFAULT_BOT" > "${BOT_DIR}/.bot_type"
chown "${OS_USERNAME}:${OS_USERNAME}" "${BOT_DIR}/.bot_type"

# -- 10. Wosbot service
echo "[10/13] Installing wosbot service..."
cat > /etc/systemd/system/wosbot.service <<EOF
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
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# -- 12. VNC
echo "[12/13] Setting up VNC..."
mkdir -p "/home/${OS_USERNAME}/.vnc"
x11vnc -storepasswd "$OS_PASSWORD" "/home/${OS_USERNAME}/.vnc/passwd" 2>/dev/null || true
chown -R "${OS_USERNAME}:${OS_USERNAME}" "/home/${OS_USERNAME}/.vnc"

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

# -- 13. Web control panel
echo "[13/13] Installing web control panel..."
mkdir -p "$WEBSERVER_DIR"
chmod -R 775 "$BOT_DIR"
chmod 666 "$TOKEN_FILE" 2>/dev/null || true

# switch-bot script is pre-substituted by build-lxc.sh / build-iso.sh
chmod +x /usr/local/bin/wosland-switch-bot.sh

# -- Create GUI flag dir
mkdir -p /etc/wosland
# Enable GUI by default on non-LXC
if [ "$IS_LXC" -eq 0 ]; then
  touch /etc/wosland/gui_enabled
fi

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
ExecStartPre=/bin/bash -c 'touch ${TOKEN_FILE} && chmod 666 ${TOKEN_FILE} && chown ${OS_USERNAME}:${OS_USERNAME} ${TOKEN_FILE}'
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
for svc in wosbot xvfb x11vnc wosland-web ssh openssh-server; do
  systemctl enable "$svc" 2>/dev/null || true
done

if [ "$IS_LXC" -eq 1 ]; then
  systemctl disable rsyslog 2>/dev/null || true
  systemctl mask rsyslog 2>/dev/null || true
fi

systemctl disable wosland-firstboot.service 2>/dev/null || true
rm -f /etc/systemd/system/wosland-firstboot.service

echo "========================================="
echo " WoslandOS Provisioning COMPLETE"
echo " $(date)"
echo "========================================="
echo " SSH  : port 22  (user: ${OS_USERNAME})"
echo " VNC  : port 5900"
echo " Web  : http://<ip>:${WEBSERVER_PORT}"
echo "========================================="

if [ "${WOSLAND_REBOOT:-1}" = "1" ] && [ "$IS_LXC" -eq 0 ]; then
  echo "Rebooting in 5 seconds..."
  sleep 5
  reboot
fi
