#!/usr/bin/env bash
# ============================================================
# WoslandOS — Update Bot Token Helper
# Run this on the Pi to quickly update your bot token:
#   sudo ./update-token.sh YOUR_TOKEN_HERE
#   or interactively: sudo ./update-token.sh
# ============================================================
set -euo pipefail

BOT_DIR="/home/wosland/bot"
TOKEN_FILE="${BOT_DIR}/bot_token.txt"
SERVICE_NAME="wosbot"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [ -n "${1:-}" ]; then
  TOKEN="$1"
else
  echo -e "${YELLOW}WoslandOS — Bot Token Updater${NC}"
  echo -n "Enter new bot token: "
  read -r TOKEN
fi

if [ -z "$TOKEN" ]; then
  echo -e "${RED}Error: token cannot be empty.${NC}"
  exit 1
fi

echo "$TOKEN" > "$TOKEN_FILE"
chmod 640 "$TOKEN_FILE"
chown "wosland:wosland" "$TOKEN_FILE"

echo -e "${GREEN}✓ Token saved to ${TOKEN_FILE}${NC}"

echo "Restarting ${SERVICE_NAME}..."
systemctl restart "$SERVICE_NAME"
sleep 2

STATUS=$(systemctl is-active "$SERVICE_NAME")
if [ "$STATUS" = "active" ]; then
  echo -e "${GREEN}✓ ${SERVICE_NAME} is running.${NC}"
else
  echo -e "${RED}✗ ${SERVICE_NAME} status: ${STATUS} — check: journalctl -u ${SERVICE_NAME} -n 30${NC}"
fi
