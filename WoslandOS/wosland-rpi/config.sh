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
REPO_BASE="https://raw.githubusercontent.com/ikketim/install/"

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

# ── Ubuntu base image ────────────────────────────────────────
# Ubuntu Server for Raspberry Pi (arm64)
UBUNTU_VERSION="24.04"
UBUNTU_IMAGE_URL="https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img.xz"
UBUNTU_IMAGE_FILE="ubuntu-raspi-base.img.xz"
