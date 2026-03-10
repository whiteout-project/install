#!/usr/bin/env bash
# ============================================================
# WoslandOS -- Bot Switcher
# Called by the web dashboard. Switches between:
#   wos-py   -- Whiteout Survival Python bot
#   wos-js   -- Whiteout Survival JavaScript bot (Node 22)
#   kingshot -- Kingshot Discord bot (Python)
#
# Usage: wosland-switch-bot.sh <bot-type>
# ============================================================
set -euo pipefail

BOT_TYPE="${1:-}"
BOT_DIR="@@BOT_DIR@@"
VENV_DIR="${BOT_DIR}/venv"
OS_USERNAME="@@OS_USERNAME@@"
SERVICE_NAME="@@SERVICE_NAME@@"
TOKEN_FILE="${BOT_DIR}/bot_token.txt"
JS_ENV_FILE="${BOT_DIR}/src/.env"
BOT_TYPE_FILE="${BOT_DIR}/.bot_type"
LOG="/var/log/wosland-switch.log"

# Bot repo URLs (substituted at build time)
BOT_MAIN_PY="@@BOT_MAIN_PY@@"
BOT_INSTALL_PY="@@BOT_INSTALL_PY@@"
BOT_JS_REPO="@@BOT_JS_REPO@@"
BOT_JS_BRANCH="@@BOT_JS_BRANCH@@"
BOT_KINGSHOT_REPO="@@BOT_KINGSHOT_REPO@@"
BOT_KINGSHOT_BRANCH="@@BOT_KINGSHOT_BRANCH@@"

exec > >(tee -a "$LOG") 2>&1
echo "========================================"
echo " Bot Switcher: ${BOT_TYPE}"
echo " $(date)"
echo "========================================"

if [[ ! "$BOT_TYPE" =~ ^(wos-py|wos-js|kingshot)$ ]]; then
  echo "ERROR: Unknown bot type '${BOT_TYPE}'"
  exit 1
fi

# ── Read current token (carry over) ─────────────────────────
CURRENT_TOKEN=""
if [ -f "$TOKEN_FILE" ]; then
  CURRENT_TOKEN=$(cat "$TOKEN_FILE" | tr -d '[:space:]')
elif [ -f "$JS_ENV_FILE" ]; then
  CURRENT_TOKEN=$(grep -oP '(?<=TOKEN=).*' "$JS_ENV_FILE" 2>/dev/null | tr -d '[:space:]' || true)
fi
echo "Token carry-over: ${CURRENT_TOKEN:+(found, ${#CURRENT_TOKEN} chars)}"
echo "Token carry-over: ${CURRENT_TOKEN:-EMPTY}"

# ── Stop current service ─────────────────────────────────────
echo "Stopping ${SERVICE_NAME}..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sleep 2

#    Remove old bot files by nuking and recreating the
#    directory, so hidden files like .git are also removed.
#    The old approach (rm -rf ./*) left .git behind, causing
#    "git clone . already exists" errors on subsequent switches.
# ────────────────────────────────────────────────────────────
echo "Removing old bot files from ${BOT_DIR}..."
rm -rf "${BOT_DIR:?}"
mkdir -p "$BOT_DIR"
chown "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"
chmod 755 "$BOT_DIR"

# ── Install new bot ──────────────────────────────────────────
case "$BOT_TYPE" in

  # ── WOS Python ─────────────────────────────────────────────
  wos-py)
    echo "Installing WOS Python bot..."
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

    # Write token
    echo "${CURRENT_TOKEN}" > "$TOKEN_FILE"
    chown "${OS_USERNAME}:${OS_USERNAME}" "$TOKEN_FILE"
    chmod 640 "$TOKEN_FILE"

    # Write service
    #         OMP_NUM_THREADS / ONNXRUNTIME_NTHREADS prevent
    #         pthread_setaffinity_np errors in LXC/VM environments.
    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
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
    ;;

  # ── WOS JavaScript ─────────────────────────────────────────
  wos-js)
    echo "Installing WOS JavaScript bot..."

    # Ensure Node 22 is available
    if ! node --version 2>/dev/null | grep -q "^v22"; then
      echo "Installing Node.js 22..."
      curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
      apt-get install -y -qq nodejs git curl jq file unzip make gcc g++ python3 python3-dev python3-pip libtool wget
    fi

    #         Ensure build tools are present for native addons
    #         (e.g. better-sqlite3 requires 'make' and gcc to
    #         compile from source when no prebuilt binary exists).
    if ! command -v make &>/dev/null; then
      echo "Installing build tools (required for native Node addons)..."
      apt-get install -y -qq build-essential python3-dev git curl jq file unzip make gcc g++ python-is-python3 python3-full libtool
    fi

    # Clone repo
    cd "$BOT_DIR"
    git clone --depth=1 --branch "$BOT_JS_BRANCH" "$BOT_JS_REPO" .
    chown -R "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"

    # Install npm dependencies
    sudo -u "$OS_USERNAME" npm install --prefix "$BOT_DIR"

    # Write .env with token
    mkdir -p "${BOT_DIR}/src"
    cat > "$JS_ENV_FILE" <<ENVEOF
TOKEN=${CURRENT_TOKEN}
ENVEOF
    chown "${OS_USERNAME}:${OS_USERNAME}" "$JS_ENV_FILE"
    chmod 640 "$JS_ENV_FILE"

    # Determine entry point (index.js or src/index.js)
    if [ -f "${BOT_DIR}/src/index.js" ]; then
      ENTRY="src/index.js"
    elif [ -f "${BOT_DIR}/index.js" ]; then
      ENTRY="index.js"
    else
      ENTRY="$(ls ${BOT_DIR}/*.js 2>/dev/null | head -1 | xargs basename || echo 'index.js')"
    fi

    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=WOSBot (Whiteout Survival - JavaScript)
After=network.target

[Service]
ExecStart=/usr/bin/node ${BOT_DIR}/${ENTRY}
WorkingDirectory=${BOT_DIR}
Restart=always
RestartSec=5
User=${OS_USERNAME}
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    ;;

  # ── Kingshot Python ────────────────────────────────────────
  kingshot)
    echo "Installing Kingshot bot..."

    # Clone repo
    cd "$BOT_DIR"
    git clone --depth=1 --branch "$BOT_KINGSHOT_BRANCH" "$BOT_KINGSHOT_REPO" .
    chown -R "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"
    chmod 755 "$BOT_DIR"

    # Install Python venv + requirements
    sudo -u "$OS_USERNAME" python3 -m venv "$VENV_DIR"
    sudo -u "$OS_USERNAME" "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    if [ -f "${BOT_DIR}/requirements.txt" ]; then
      sudo -u "$OS_USERNAME" "$VENV_DIR/bin/pip" install --quiet -r "${BOT_DIR}/requirements.txt"
    fi
    chown -R "${OS_USERNAME}:${OS_USERNAME}" "$BOT_DIR"

    # Write token
    echo "${CURRENT_TOKEN}" > "$TOKEN_FILE"
    chown "${OS_USERNAME}:${OS_USERNAME}" "$TOKEN_FILE"
    chmod 775 "$TOKEN_FILE"

    # FIX #1: OMP_NUM_THREADS / ONNXRUNTIME_NTHREADS prevent
    #         pthread_setaffinity_np errors in LXC/VM environments.
    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=WOSBot (Kingshot)
After=network.target

[Service]
ExecStart=${VENV_DIR}/bin/python3 ${BOT_DIR}/main.py
WorkingDirectory=${BOT_DIR}
Restart=always
RestartSec=5
User=${OS_USERNAME}
Environment="OMP_NUM_THREADS=1"
Environment="ONNXRUNTIME_NTHREADS=1"

[Install]
WantedBy=multi-user.target
EOF
    ;;
esac

# ── Persist bot type ─────────────────────────────────────────
echo "$BOT_TYPE" > "$BOT_TYPE_FILE"
chown "${OS_USERNAME}:${OS_USERNAME}" "$BOT_TYPE_FILE"

# ── Reload and restart service ───────────────────────────────
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"
sleep 3

STATUS=$(systemctl is-active "$SERVICE_NAME" || true)
echo "========================================"
echo " Switch complete: ${BOT_TYPE}"
echo " Service status: ${STATUS}"
echo "========================================"
exit 0
