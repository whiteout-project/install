#!/usr/bin/env bash
# ============================================================
# WoslandOS x86 / LXC — Central Configuration
# Edit ONLY this file when repo links or credentials change,
# then run ./build-iso.sh or ./build-lxc.sh to rebuild.
# ============================================================

# ── System identity ──────────────────────────────────────────
OS_USERNAME="wosland"
OS_PASSWORD="W0sL@nd"
OS_HOSTNAME="Wosland-os-server"

# ── Source repository (update these when links change) ───────
REPO_BASE="https://raw.githubusercontent.com/ikketim/install/"

BOT_MAIN_PY="https://raw.githubusercontent.com/whiteout-project/bot/main/main.py"
BOT_INSTALL_PY="https://raw.githubusercontent.com/whiteout-project/install/main/install.py"

BACKGROUND_IMAGE_URL="${REPO_BASE}/woslandOS/etc/woslandOS.png"

# ── Install paths (on the target machine) ───────────────────
BOT_DIR="/home/${OS_USERNAME}/bot"
VENV_DIR="${BOT_DIR}/venv"
SERVICE_NAME="wosbot"
TOKEN_FILE="${BOT_DIR}/bot_token.txt"
WEBSERVER_DIR="/opt/wosland-webserver"
WEBSERVER_PORT="8080"

# ── Desktop environment ──────────────────────────────────────
# Options: xfce  (lightweight, recommended)
#          lxde  (very lightweight)
#          mate  (classic desktop)
DESKTOP="xfce"

# ── Ubuntu base for ISO builds ───────────────────────────────
UBUNTU_VERSION="24.04"
UBUNTU_ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
UBUNTU_ISO_FILE="ubuntu-server-base.iso"

# ── LXC template (for Proxmox builds) ───────────────────────
# This is the Turnkey/Ubuntu template tag used by pveam
LXC_TEMPLATE="ubuntu-24.04-standard"
