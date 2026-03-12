#!/usr/bin/env bash
# ============================================================
# WoslandOS Raspberry Pi -- Image Builder
#
# Requirements (on your build machine):
#   sudo apt install xz-utils kpartx qemu-utils qemu-user-static
#                   binfmt-support wget curl
#
# Usage:
#   sudo ./build.sh            -- build using current config.sh
#   sudo ./build.sh --clean    -- remove cached base image and rebuild
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

WORK_DIR="${SCRIPT_DIR}/build-tmp"
OUTPUT_DIR="${SCRIPT_DIR}/output"
BASE_IMG="${WORK_DIR}/${UBUNTU_IMAGE_FILE}"
WORK_IMG="${WORK_DIR}/wosland-os-work.img"
FINAL_IMG="${OUTPUT_DIR}/wosland-os-$(date +%Y%m%d).img"
MOUNT_BOOT="${WORK_DIR}/mnt-boot"
MOUNT_ROOT="${WORK_DIR}/mnt-root"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

cleanup() {
  info "Cleaning up mounts..."
  sync || true
  umount "${MOUNT_ROOT}/proc"          2>/dev/null || true
  umount "${MOUNT_ROOT}/sys"           2>/dev/null || true
  umount "${MOUNT_ROOT}/dev/pts"       2>/dev/null || true
  umount "${MOUNT_ROOT}/dev"           2>/dev/null || true
  umount "${MOUNT_ROOT}/boot/firmware" 2>/dev/null || true
  umount "${MOUNT_ROOT}"               2>/dev/null || true
  umount "${MOUNT_BOOT}"               2>/dev/null || true
  kpartx -d "$WORK_IMG"                2>/dev/null || true
}
trap cleanup EXIT

check_deps() {
  info "Checking build dependencies..."
  local missing=()
  for cmd in xz kpartx qemu-aarch64-static wget curl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing tools: ${missing[*]}\nInstall with:\n  sudo apt install xz-utils kpartx qemu-user-static binfmt-support wget"
  fi
  [ "$EUID" -eq 0 ] || error "This script must be run as root (sudo ./build.sh)"
}

download_base() {
  mkdir -p "$WORK_DIR" "$OUTPUT_DIR"
  if [ "${1:-}" = "--clean" ] && [ -f "$BASE_IMG" ]; then
    info "Removing cached base image..."
    rm -f "$BASE_IMG"
  fi
  if [ ! -f "$BASE_IMG" ]; then
    UBUNTU_IMAGE_URL=$(resolve_ubuntu_image_url)
    info "Downloading ${UBUNTU_IMAGE_URL##*/}..."
    wget --show-progress -O "$BASE_IMG" "$UBUNTU_IMAGE_URL"
  else
    info "Using cached base image."
  fi
}

prepare_image() {
  info "Decompressing base image..."
  xz -dk "$BASE_IMG" --stdout > "$WORK_IMG"
  info "Working image ready: $(du -sh "$WORK_IMG" | cut -f1)"
}

mount_image() {
  info "Mounting image partitions..."
  LOOP_DEVS=$(kpartx -av "$WORK_IMG" | awk '{print $3}')
  BOOT_PART="/dev/mapper/$(echo "$LOOP_DEVS" | head -1)"
  ROOT_PART="/dev/mapper/$(echo "$LOOP_DEVS" | tail -1)"

  mkdir -p "$MOUNT_BOOT" "$MOUNT_ROOT"
  mount "$ROOT_PART" "$MOUNT_ROOT"
  mount "$BOOT_PART" "${MOUNT_ROOT}/boot/firmware" 2>/dev/null || \
    mount "$BOOT_PART" "$MOUNT_BOOT"

  mount --bind /dev     "${MOUNT_ROOT}/dev"
  mount --bind /dev/pts "${MOUNT_ROOT}/dev/pts"
  mount --bind /proc    "${MOUNT_ROOT}/proc"
  mount --bind /sys     "${MOUNT_ROOT}/sys"

  cp /usr/bin/qemu-aarch64-static "${MOUNT_ROOT}/usr/bin/" 2>/dev/null || \
  cp /usr/bin/qemu-arm-static     "${MOUNT_ROOT}/usr/bin/" 2>/dev/null || \
    warn "qemu-arm-static not found -- chroot may fail on non-ARM host"
}

inject_overlay() {
  info "Injecting rootfs overlay files..."
  OVERLAY="${SCRIPT_DIR}/rootfs-overlay"
  cp -r "${OVERLAY}/." "${MOUNT_ROOT}/"

  FIRSTBOOT="${MOUNT_ROOT}/usr/local/bin/wosland-firstboot.sh"

  # FIX: @@SERVICE_FILE@@ was referenced in sed substitutions but
  # never defined in config.sh, leaving a raw placeholder in the
  # provisioned image. Removed the broken substitution line.
  # VENV_DIR is derived from BOT_DIR so it is substituted here
  # explicitly rather than relying on config.sh to export it.
  local VENV_DIR="${BOT_DIR}/venv"

  sed -i "s|@@OS_USERNAME@@|${OS_USERNAME}|g"                    "$FIRSTBOOT"
  sed -i "s|@@OS_PASSWORD@@|${OS_PASSWORD}|g"                    "$FIRSTBOOT"
  sed -i "s|@@OS_HOSTNAME@@|${OS_HOSTNAME}|g"                    "$FIRSTBOOT"
  sed -i "s|@@BOT_MAIN_PY@@|${BOT_MAIN_PY}|g"                   "$FIRSTBOOT"
  sed -i "s|@@BOT_INSTALL_PY@@|${BOT_INSTALL_PY}|g"             "$FIRSTBOOT"
  sed -i "s|@@BOT_JS_REPO@@|${BOT_JS_REPO}|g"                   "$FIRSTBOOT"
  sed -i "s|@@BOT_JS_BRANCH@@|${BOT_JS_BRANCH}|g"               "$FIRSTBOOT"
  sed -i "s|@@BOT_KINGSHOT_REPO@@|${BOT_KINGSHOT_REPO}|g"       "$FIRSTBOOT"
  sed -i "s|@@BOT_KINGSHOT_BRANCH@@|${BOT_KINGSHOT_BRANCH}|g"   "$FIRSTBOOT"
  sed -i "s|@@DEFAULT_BOT@@|${DEFAULT_BOT}|g"                   "$FIRSTBOOT"
  sed -i "s|@@BACKGROUND_IMAGE_URL@@|${BACKGROUND_IMAGE_URL}|g" "$FIRSTBOOT"
  sed -i "s|@@BOT_DIR@@|${BOT_DIR}|g"                           "$FIRSTBOOT"
  sed -i "s|@@VENV_DIR@@|${VENV_DIR}|g"                         "$FIRSTBOOT"
  sed -i "s|@@SERVICE_NAME@@|${SERVICE_NAME}|g"                  "$FIRSTBOOT"
  sed -i "s|@@TOKEN_FILE@@|${TOKEN_FILE}|g"                      "$FIRSTBOOT"
  sed -i "s|@@WEBSERVER_DIR@@|${WEBSERVER_DIR}|g"                "$FIRSTBOOT"
  sed -i "s|@@WEBSERVER_PORT@@|${WEBSERVER_PORT}|g"              "$FIRSTBOOT"
  # NOTE: @@SERVICE_FILE@@ removed -- it was never defined in config.sh
  #       and left a raw placeholder in the provisioned image.
  #       If wosland-firstboot.sh references @@SERVICE_FILE@@, replace
  #       those occurrences with @@SERVICE_NAME@@ in that script.

  chmod +x "$FIRSTBOOT"

  # ── Substitute switch-bot script ────────────────────────────
  SWITCHBOT="${MOUNT_ROOT}/usr/local/bin/wosland-switch-bot.sh"
  if [ -f "$SWITCHBOT" ]; then
    sed -i "s|@@OS_USERNAME@@|${OS_USERNAME}|g"                  "$SWITCHBOT"
    sed -i "s|@@BOT_DIR@@|${BOT_DIR}|g"                         "$SWITCHBOT"
    sed -i "s|@@SERVICE_NAME@@|${SERVICE_NAME}|g"                "$SWITCHBOT"
    sed -i "s|@@TOKEN_FILE@@|${TOKEN_FILE}|g"                    "$SWITCHBOT"
    sed -i "s|@@BOT_MAIN_PY@@|${BOT_MAIN_PY}|g"                 "$SWITCHBOT"
    sed -i "s|@@BOT_INSTALL_PY@@|${BOT_INSTALL_PY}|g"           "$SWITCHBOT"
    sed -i "s|@@BOT_JS_REPO@@|${BOT_JS_REPO}|g"                 "$SWITCHBOT"
    sed -i "s|@@BOT_JS_BRANCH@@|${BOT_JS_BRANCH}|g"             "$SWITCHBOT"
    sed -i "s|@@BOT_KINGSHOT_REPO@@|${BOT_KINGSHOT_REPO}|g"     "$SWITCHBOT"
    sed -i "s|@@BOT_KINGSHOT_BRANCH@@|${BOT_KINGSHOT_BRANCH}|g" "$SWITCHBOT"
    chmod +x "$SWITCHBOT"
  else
    warn "wosland-switch-bot.sh not found in rootfs-overlay -- skipping substitution"
  fi

  WEBSERVER_DEST="${MOUNT_ROOT}${WEBSERVER_DIR}"
  mkdir -p "$WEBSERVER_DEST"
  cp "${SCRIPT_DIR}/webserver/app.py" "$WEBSERVER_DEST/"
  chmod +x "${WEBSERVER_DEST}/app.py"

  # ── Ensure all injected scripts have Unix line endings ───────
  # Prevents /usr/bin/env: 'bash\r' errors if scripts were edited
  # on Windows or built from WSL against a Windows filesystem.
  find "${MOUNT_ROOT}/usr/local/bin" -name "*.sh" \
    -exec sed -i 's/\r//' {} + 2>/dev/null || true

  info "Overlay injection complete."
}

configure_chroot() {
  info "Configuring systemd in chroot..."
  chroot "${MOUNT_ROOT}" /bin/bash -c "
    systemctl enable wosland-firstboot.service 2>/dev/null || true
    touch /etc/cloud/cloud-init.disabled 2>/dev/null || true
  " || warn "chroot configuration partially failed (may be OK on ARM host)"
}

finalize() {
  info "Syncing and unmounting..."
  sync
  cleanup

  info "Compressing final image..."
  xz -T0 -v "$WORK_IMG"
  mv "${WORK_IMG}.xz" "${FINAL_IMG}.xz"

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   WoslandOS image built successfully!        ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Image: ${YELLOW}${FINAL_IMG}.xz${NC}"
  echo -e "  Flash: ${YELLOW}xzcat ${FINAL_IMG}.xz | sudo dd of=/dev/sdX bs=4M status=progress${NC}"
  echo "  Or use Raspberry Pi Imager with the 'Use custom' option."
  echo ""
}

main() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║        WoslandOS RPi Image Builder           ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  check_deps
  download_base "${1:-}"
  prepare_image
  mount_image
  inject_overlay
  configure_chroot
  finalize
}

main "$@"