#!/usr/bin/env bash
# ============================================================
# WoslandOS x86 / LXC -- Central Configuration
# Edit ONLY this file when repo links or credentials change.
# ============================================================

# -- System identity -----------------------------------------
OS_USERNAME="wosland"
OS_PASSWORD="W0sL@nd"
OS_HOSTNAME="Wosland-os-server"

# -- Source repository ---------------------------------------
REPO_BASE="https://raw.githubusercontent.com/ikketim/install/main"

# -- Bot repositories ----------------------------------------
# WOS Python bot
BOT_MAIN_PY="https://raw.githubusercontent.com/whiteout-project/bot/main/main.py"
BOT_INSTALL_PY="https://raw.githubusercontent.com/whiteout-project/install/main/install.py"

# WOS JavaScript bot
BOT_JS_REPO="https://github.com/whiteout-project/Whiteout-Survival-Discord-Bot"
BOT_JS_BRANCH="main"

# Kingshot bot
BOT_KINGSHOT_REPO="https://github.com/kingshot-project/Kingshot-Discord-Bot"
BOT_KINGSHOT_BRANCH="main"

# Default bot on first install (wos-py | wos-js | kingshot)
DEFAULT_BOT="wos-py"

# -- Background image ----------------------------------------
BACKGROUND_IMAGE_URL="${REPO_BASE}/WoslandOS/etc/woslandOS.png"

# -- Install paths (on the target machine) -------------------
BOT_DIR="/home/${OS_USERNAME}/bot"
VENV_DIR="${BOT_DIR}/venv"
SERVICE_NAME="wosbot"
TOKEN_FILE="${BOT_DIR}/bot_token.txt"
WEBSERVER_DIR="/opt/wosland-webserver"
WEBSERVER_PORT="8080"

# -- Desktop environment -------------------------------------
DESKTOP="xfce"

# -- Ubuntu base for ISO builds ------------------------------
UBUNTU_SERIES="24.04"
UBUNTU_ISO_FILE="ubuntu-server-base.iso"

resolve_ubuntu_iso_url() {
  echo "Auto-detecting latest Ubuntu ${UBUNTU_SERIES} ISO..." >&2
  local index_url="https://releases.ubuntu.com/${UBUNTU_SERIES}/"
  local iso_name
  iso_name=$(wget -qO- "$index_url" \
    | grep -oP "ubuntu-[0-9]+\.[0-9]+\.[0-9]+-live-server-amd64\.iso" \
    | grep -vE 'torrent|zsync' \
    | sort -V | tail -1)
  if [ -z "$iso_name" ]; then
    echo "ERROR: Could not detect Ubuntu ${UBUNTU_SERIES} ISO from ${index_url}" >&2
    exit 1
  fi
  echo "  -> ${iso_name}" >&2
  echo "${index_url}${iso_name}"
}

# -- LXC template --------------------------------------------
LXC_TEMPLATE="ubuntu-24.04-standard"
