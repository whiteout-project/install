#!/usr/bin/env bash
# ============================================================
# WoslandOS -- Update Bot Token Helper
# Usage (on the Pi):
#   sudo ./update-token.sh YOUR_TOKEN
#   or interactively: sudo ./update-token.sh
# ============================================================
set -euo pipefail

BOT_DIR="/home/wosland/bot"
TOKEN_FILE="${BOT_DIR}/bot_token.txt"
SERVICE_NAME="wosbot"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

if [ -n "${1:-}" ]; then
  TOKEN="$1"
else
  echo -e "WoslandOS -- Bot Token Updater"
  echo -n "Enter new bot token: "
  read -r TOKEN
fi

if [ -z "$TOKEN" ]; then
  echo -e "${RED}Error: token cannot be empty.${NC}"
  exit 1
fi

echo "$TOKEN" > "$TOKEN_FILE"
# 644: readable by root (webserver) and wosland (bot), consistent with
# permissions set during provisioning and by app.py after token saves.
chmod 644 "$TOKEN_FILE"
chown "wosland:wosland" "$TOKEN_FILE"
echo -e "${GREEN}Token saved.${NC}"

systemctl restart "$SERVICE_NAME"
sleep 2
STATUS=$(systemctl is-active "$SERVICE_NAME")
if [ "$STATUS" = "active" ]; then
  echo -e "${GREEN}${SERVICE_NAME} is running.${NC}"
else
  echo -e "${RED}${SERVICE_NAME} status: ${STATUS} -- check: journalctl -u ${SERVICE_NAME} -n 30${NC}"
fi
