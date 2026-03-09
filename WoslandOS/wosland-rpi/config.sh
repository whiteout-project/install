#!/usr/bin/env bash
# ============================================================
# WoslandOS Image Builder — Central Configuration
# Edit this file when repo links or credentials change
# ============================================================

# ── System identity ─────────────────────────────────────────
OS_USERNAME="wosland"
OS_PASSWORD="W0sL@nd"
OS_HOSTNAME="Wosland-os-server"

# ── Source repository (update these when links change) ──────
REPO_BASE="https://raw.githubusercontent.com/ikketim/install/main"

BOT_MAIN_PY="https://raw.githubusercontent.com/whiteout-project/bot/main/main.py"
BOT_INSTALL_PY="https://raw.githubusercontent.com/whiteout-project/install/main/install.py"

BACKGROUND_IMAGE_URL="${REPO_BASE}/woslandOS/etc/woslandOS.png"
SERVICE_FILE_URL="${REPO_BASE}/woslandOS/etc/wosbot.service"

# ── Install paths (on the Pi) ────────────────────────────────
BOT_DIR="/home/${OS_USERNAME}/bot"
VENV_DIR="${BOT_DIR}/venv"
SERVICE_NAME="wosbot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TOKEN_FILE="${BOT_DIR}/bot_token.txt"
WEBSERVER_DIR="/opt/wosland-webserver"
WEBSERVER_PORT="8080"

# -- Ubuntu base image ---------------------------------------
# Only change UBUNTU_SERIES to switch LTS track (e.g. 22.04, 26.04).
# The exact point-release image is auto-detected at build time.
UBUNTU_SERIES="24.04"
UBUNTU_IMAGE_FILE="ubuntu-raspi-base.img.xz"

resolve_ubuntu_image_url() {
  echo "Auto-detecting latest Ubuntu ${UBUNTU_SERIES} Raspberry Pi image..." >&2
  local index_url="https://cdimage.ubuntu.com/releases/${UBUNTU_SERIES}/release/"
  local img_name
  img_name=$(wget -qO- "$index_url" \
    | grep -oP "ubuntu-[0-9]+\.[0-9]+\.[0-9]+-preinstalled-server-arm64\+raspi\.img\.xz" \
    | sort -V | tail -1)
  if [ -z "$img_name" ]; then
    echo "ERROR: Could not detect Ubuntu ${UBUNTU_SERIES} Pi image from ${index_url}" >&2
    exit 1
  fi
  echo "  -> ${img_name}" >&2
  echo "${index_url}${img_name}"
}
