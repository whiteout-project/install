#!/usr/bin/env bash
# ============================================================
# WoslandOS x86 / LXC -- Central Configuration
# Edit ONLY this file when repo links or credentials change,
# then run ./build-iso.sh or ./build-lxc.sh to rebuild.
# ============================================================

# -- System identity -----------------------------------------
OS_USERNAME="wosland"
OS_PASSWORD="W0sL@nd"
OS_HOSTNAME="Wosland-os-server"

# -- Source repository (update these when links change) ------
REPO_BASE="https://raw.githubusercontent.com/ikketim/install/main"

BOT_MAIN_PY="https://raw.githubusercontent.com/whiteout-project/bot/main/main.py"
BOT_INSTALL_PY="https://raw.githubusercontent.com/whiteout-project/install/main/install.py"

BACKGROUND_IMAGE_URL="${REPO_BASE}/woslandOS/etc/woslandOS.png"

# -- Install paths (on the target machine) -------------------
BOT_DIR="/home/${OS_USERNAME}/bot"
VENV_DIR="${BOT_DIR}/venv"
SERVICE_NAME="wosbot"
TOKEN_FILE="${BOT_DIR}/bot_token.txt"
WEBSERVER_DIR="/opt/wosland-webserver"
WEBSERVER_PORT="8080"

# -- Desktop environment -------------------------------------
# Options: xfce  (lightweight, recommended)
#          lxde  (very lightweight)
#          mate  (classic desktop)
DESKTOP="xfce"

# -- Ubuntu base for ISO builds ------------------------------
# Only change UBUNTU_SERIES to switch LTS track (e.g. 22.04, 26.04).
# The exact point-release ISO is auto-detected at build time.
UBUNTU_SERIES="24.04"
UBUNTU_ISO_FILE="ubuntu-server-base.iso"

resolve_ubuntu_iso_url() {
  echo "Auto-detecting latest Ubuntu ${UBUNTU_SERIES} ISO..." >&2
  local index_url="https://releases.ubuntu.com/${UBUNTU_SERIES}/"
  local iso_name
  iso_name=$(wget -qO- "$index_url" \
    | grep -oP "ubuntu-[0-9]+\.[0-9]+\.[0-9]+-live-server-amd64\.iso" \
    | grep -v 'torrent|zsync' \
    | sort -V | tail -1)
  if [ -z "$iso_name" ]; then
    echo "ERROR: Could not detect Ubuntu ${UBUNTU_SERIES} ISO from ${index_url}" >&2
    exit 1
  fi
  echo "  -> ${iso_name}" >&2
  echo "${index_url}${iso_name}"
}

# -- LXC template (for Proxmox builds) -----------------------
# This is the Ubuntu template tag used by pveam
LXC_TEMPLATE="ubuntu-24.04-standard"
