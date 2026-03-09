#!/usr/bin/env bash
# ============================================================
# WoslandOS — Proxmox LXC Provisioner
#
# Run this on your Proxmox HOST (not inside the container).
# It creates an LXC container, configures it, and runs the
# full WoslandOS provisioning inside it automatically.
#
# Usage (on Proxmox host, as root):
#   ./build-lxc.sh
#   ./build-lxc.sh --ctid 200   — use a specific container ID
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# ── LXC settings ─────────────────────────────────────────────
CTID="${CTID:-$(pvesh get /cluster/nextid 2>/dev/null || echo 200)}"
CT_STORAGE="${CT_STORAGE:-local-lvm}"   # Proxmox storage for rootfs
CT_DISK_SIZE="${CT_DISK_SIZE:-20}"       # GB
CT_RAM="${CT_RAM:-2048}"                 # MB
CT_CORES="${CT_CORES:-2}"
CT_BRIDGE="${CT_BRIDGE:-vmbr0}"
CT_VLAN="${CT_VLAN:-}"                   # Optional: set to VLAN tag e.g. "10"
CT_IP="${CT_IP:-dhcp}"                   # "dhcp" or "192.168.1.50/24"
CT_GW="${CT_GW:-}"                       # Gateway if using static IP

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[LXC]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# Parse args
for arg in "$@"; do
  case $arg in
    --ctid=*) CTID="${arg#*=}" ;;
    --ctid)   shift; CTID="$1" ;;
  esac
done

check_deps() {
  [ "$EUID" -eq 0 ] || error "Run as root on the Proxmox host"
  command -v pct   &>/dev/null || error "pct not found — run this on a Proxmox host"
  command -v pveam &>/dev/null || error "pveam not found — run this on a Proxmox host"
}

download_template() {
  info "Checking for Ubuntu 24.04 LXC template..." 
  local tmpl_name
  tmpl_name=$(pveam available --section system 2>/dev/null \
    | grep "ubuntu-24.04-standard" | tail -1 | awk '{print $2}')

  if [ -z "$tmpl_name" ]; then
    tmpl_name="ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  fi

  if ! pveam list local 2>/dev/null | grep -q "ubuntu-24.04"; then
    info "Downloading template: ${tmpl_name}" 
    pveam download local "$tmpl_name" >&2
  else
    info "Template already downloaded." 
  fi

  # Return just the storage:vztmpl/filename reference
  local final
  final=$(pveam list local 2>/dev/null | grep "ubuntu-24.04" | tail -1 | awk '{print $1}')
  echo "$final"
}

create_container() {
  local template="$1"

  info "Creating LXC container (ID: ${CTID})..."

  # Build network arg
  NET_ARG="name=eth0,bridge=${CT_BRIDGE}"
  if [ "$CT_IP" = "dhcp" ]; then
    NET_ARG="${NET_ARG},ip=dhcp"
  else
    NET_ARG="${NET_ARG},ip=${CT_IP}"
    [ -n "$CT_GW" ] && NET_ARG="${NET_ARG},gw=${CT_GW}"
  fi
  [ -n "$CT_VLAN" ] && NET_ARG="${NET_ARG},tag=${CT_VLAN}"

  pct create "$CTID" "$template" \
    --hostname "$OS_HOSTNAME" \
    --password "$OS_PASSWORD" \
    --storage "$CT_STORAGE" \
    --rootfs "${CT_STORAGE}:${CT_DISK_SIZE}" \
    --memory "$CT_RAM" \
    --cores "$CT_CORES" \
    --net0 "$NET_ARG" \
    --unprivileged 1 \
    --features nesting=1 \
    --ostype ubuntu \
    --start 0

  # Enable nesting + tun for the container (needed for VNC virtual display)
  pct set "$CTID" --features nesting=1
}

inject_and_run() {
  info "Starting container..."
  pct start "$CTID"
  sleep 8  # Wait for systemd to be ready

  info "Copying provisioning files into container..."

  # Build substituted provisioning script
  PROVISION_TMP=$(mktemp)
  sed \
    -e "s|@@OS_USERNAME@@|${OS_USERNAME}|g" \
    -e "s|@@OS_PASSWORD@@|${OS_PASSWORD}|g" \
    -e "s|@@OS_HOSTNAME@@|${OS_HOSTNAME}|g" \
    -e "s|@@BOT_MAIN_PY@@|${BOT_MAIN_PY}|g" \
    -e "s|@@BOT_INSTALL_PY@@|${BOT_INSTALL_PY}|g" \
    -e "s|@@BACKGROUND_IMAGE_URL@@|${BACKGROUND_IMAGE_URL}|g" \
    -e "s|@@DESKTOP@@|${DESKTOP}|g" \
    -e "s|@@BOT_DIR@@|${BOT_DIR}|g" \
    -e "s|@@VENV_DIR@@|${VENV_DIR}|g" \
    -e "s|@@SERVICE_NAME@@|${SERVICE_NAME}|g" \
    -e "s|@@TOKEN_FILE@@|${TOKEN_FILE}|g" \
    -e "s|@@WEBSERVER_DIR@@|${WEBSERVER_DIR}|g" \
    -e "s|@@WEBSERVER_PORT@@|${WEBSERVER_PORT}|g" \
    "${SCRIPT_DIR}/rootfs-overlay/usr/local/bin/wosland-provision.sh" \
    > "$PROVISION_TMP"

  # Push files into container via pct push
  pct push "$CTID" "$PROVISION_TMP" /usr/local/bin/wosland-provision.sh --perms 0755
  pct exec "$CTID" -- mkdir -p "$WEBSERVER_DIR"
  pct push "$CTID" "${SCRIPT_DIR}/webserver/app.py" "${WEBSERVER_DIR}/app.py" --perms 0755

  rm -f "$PROVISION_TMP"

  info "Running provisioning inside container (this takes 5–15 minutes)..."
  info "Follow logs with:  pct exec ${CTID} -- tail -f /var/log/wosland-setup.log"
  echo ""

  # Run with WOSLAND_REBOOT=0 so it doesn't reboot inside LXC
  pct exec "$CTID" -- bash -c "WOSLAND_REBOOT=0 /usr/local/bin/wosland-provision.sh"

  # Get container IP
  CT_ASSIGNED_IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "check Proxmox UI")

  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   WoslandOS LXC container ready! 🎉               ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Container ID : ${YELLOW}${CTID}${NC}"
  echo -e "  IP Address   : ${YELLOW}${CT_ASSIGNED_IP}${NC}"
  echo ""
  echo -e "  🌐 Web panel : ${YELLOW}http://${CT_ASSIGNED_IP}:${WEBSERVER_PORT}${NC}"
  echo -e "  🔒 SSH       : ${YELLOW}ssh ${OS_USERNAME}@${CT_ASSIGNED_IP}${NC}"
  echo -e "  🖥️  VNC       : ${YELLOW}${CT_ASSIGNED_IP}:5900${NC}  (password: ${OS_PASSWORD})"
  echo ""
  echo -e "  Manage with pct:"
  echo -e "    pct stop  ${CTID}    pct start ${CTID}    pct destroy ${CTID}"
  echo ""
}

main() {
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║     WoslandOS Proxmox LXC Builder                 ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  check_deps
  TEMPLATE=$(download_template)
  create_container "$TEMPLATE"
  inject_and_run
}

main "$@"
