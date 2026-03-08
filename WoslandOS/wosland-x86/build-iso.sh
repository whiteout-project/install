#!/usr/bin/env bash
# ============================================================
# WoslandOS x86 — ISO Builder
#
# Produces a fully unattended install ISO for bare-metal PCs,
# VMs, and Proxmox VMs.  Boot it, walk away — the machine
# installs Ubuntu, then the firstboot service installs the
# desktop, bot, VNC, SSH, and web panel automatically.
#
# Requirements (on build machine — Ubuntu/Debian):
#   sudo apt install xorriso isolinux syslinux-utils \
#                   squashfs-tools openssl wget curl
#
# Usage:
#   sudo ./build-iso.sh           — build with current config.sh
#   sudo ./build-iso.sh --clean   — remove cached base ISO first
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

WORK_DIR="${SCRIPT_DIR}/build-tmp/iso"
OUTPUT_DIR="${SCRIPT_DIR}/output"
BASE_ISO="${SCRIPT_DIR}/build-tmp/${UBUNTU_ISO_FILE}"
FINAL_ISO="${OUTPUT_DIR}/wosland-os-x86-$(date +%Y%m%d).iso"
EXTRACT_DIR="${WORK_DIR}/iso-extract"
CUSTOM_DIR="${WORK_DIR}/iso-custom"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[ISO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

cleanup() {
  umount "${EXTRACT_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

check_deps() {
  info "Checking dependencies..."
  [ "$EUID" -eq 0 ] || error "Run as root: sudo ./build-iso.sh"
  for cmd in xorriso wget openssl; do
    command -v "$cmd" &>/dev/null || error "Missing: $cmd  →  sudo apt install xorriso wget openssl"
  done
}

download_iso() {
  mkdir -p "${SCRIPT_DIR}/build-tmp" "$OUTPUT_DIR"
  if [ "${1:-}" = "--clean" ] && [ -f "$BASE_ISO" ]; then
    info "Removing cached ISO..."
    rm -f "$BASE_ISO"
  fi
  if [ ! -f "$BASE_ISO" ]; then
    info "Downloading Ubuntu ${UBUNTU_VERSION} server ISO..."
    wget --show-progress -O "$BASE_ISO" "$UBUNTU_ISO_URL"
  else
    info "Using cached base ISO."
  fi
}

extract_iso() {
  info "Extracting base ISO..."
  mkdir -p "$EXTRACT_DIR" "$CUSTOM_DIR"
  # Mount ISO read-only then rsync to writable dir
  mount -o loop,ro "$BASE_ISO" "$EXTRACT_DIR"
  rsync -a --exclude=/casper/filesystem.squashfs "$EXTRACT_DIR/" "$CUSTOM_DIR/"
  cp "$EXTRACT_DIR/casper/filesystem.squashfs" "${CUSTOM_DIR}/casper/"
  umount "$EXTRACT_DIR"
}

inject_autoinstall() {
  info "Injecting autoinstall configuration..."

  # Generate password hash
  PW_HASH=$(echo -n "$OS_PASSWORD" | openssl passwd -6 -stdin)

  # Substitute placeholders in user-data
  USERDATA_SRC="${SCRIPT_DIR}/iso-builder/user-data"
  USERDATA_DST="${CUSTOM_DIR}/autoinstall/user-data"
  METADATA_DST="${CUSTOM_DIR}/autoinstall/meta-data"
  mkdir -p "${CUSTOM_DIR}/autoinstall"

  sed \
    -e "s|@@OS_USERNAME@@|${OS_USERNAME}|g" \
    -e "s|@@OS_PASSWORD_HASH@@|${PW_HASH}|g" \
    -e "s|@@OS_HOSTNAME@@|${OS_HOSTNAME}|g" \
    -e "s|@@WEBSERVER_DIR@@|${WEBSERVER_DIR}|g" \
    "$USERDATA_SRC" > "$USERDATA_DST"

  sed -e "s|@@OS_HOSTNAME@@|${OS_HOSTNAME}|g" \
    "${SCRIPT_DIR}/iso-builder/meta-data" > "$METADATA_DST"

  # Inject provisioning payload into a /wosland dir on the ISO
  PAYLOAD_DIR="${CUSTOM_DIR}/wosland"
  mkdir -p "$PAYLOAD_DIR"

  # Substitute config into provisioning script
  PROVISION_SRC="${SCRIPT_DIR}/rootfs-overlay/usr/local/bin/wosland-provision.sh"
  PROVISION_DST="${PAYLOAD_DIR}/wosland-provision.sh"
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
    "$PROVISION_SRC" > "$PROVISION_DST"
  chmod +x "$PROVISION_DST"

  # Copy web app
  cp "${SCRIPT_DIR}/webserver/app.py" "${PAYLOAD_DIR}/app.py"

  # Copy firstboot service
  cp "${SCRIPT_DIR}/rootfs-overlay/etc/systemd/system/wosland-firstboot.service" \
     "${PAYLOAD_DIR}/wosland-firstboot.service"
}

patch_grub() {
  info "Patching GRUB to boot autoinstall automatically..."

  GRUB_CFG="${CUSTOM_DIR}/boot/grub/grub.cfg"
  [ -f "$GRUB_CFG" ] || GRUB_CFG="${CUSTOM_DIR}/grub/grub.cfg"

  # Prepend an autoinstall menu entry at the top of grub.cfg
  AUTOINSTALL_ENTRY='
set default="0"
set timeout=5

menuentry "WoslandOS — Automated Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall "ds=nocloud;s=/cdrom/autoinstall/" ---
    initrd  /casper/initrd
}
'
  # Backup original
  cp "$GRUB_CFG" "${GRUB_CFG}.orig"
  echo "$AUTOINSTALL_ENTRY" | cat - "$GRUB_CFG" > /tmp/grub_new.cfg
  mv /tmp/grub_new.cfg "$GRUB_CFG"
}

build_iso() {
  info "Building final ISO with xorriso..."
  mkdir -p "$OUTPUT_DIR"

  # Grab EFI and MBR boot data from original ISO
  MBR_IMG="${WORK_DIR}/mbr.img"
  EFI_IMG="${WORK_DIR}/efi.img"
  dd if="$BASE_ISO" bs=1 count=432 of="$MBR_IMG" 2>/dev/null

  # Find EFI partition offset in original ISO
  EFI_OFFSET=$(fdisk -l "$BASE_ISO" 2>/dev/null | awk '/EFI/ {print $2}')
  EFI_SIZE=$(fdisk -l "$BASE_ISO" 2>/dev/null | awk '/EFI/ {print $4}')
  if [ -n "$EFI_OFFSET" ]; then
    dd if="$BASE_ISO" bs=512 skip="$EFI_OFFSET" count="$EFI_SIZE" of="$EFI_IMG" 2>/dev/null
    EFI_ARGS="-append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ${EFI_IMG}"
  else
    EFI_ARGS=""
    warn "Could not extract EFI partition — ISO may not be UEFI-bootable"
  fi

  xorriso -as mkisofs \
    -r \
    -V "WoslandOS_x86" \
    -o "$FINAL_ISO" \
    --grub2-mbr "$MBR_IMG" \
    -partition_offset 16 \
    --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$EFI_IMG" \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c '/boot.catalog' \
    -b '/boot/grub/i386-pc/eltorito.img' \
      -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
      -no-emul-boot \
    "$CUSTOM_DIR" 2>/dev/null || \
  xorriso -as mkisofs \
    -r -V "WoslandOS_x86" \
    -o "$FINAL_ISO" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$CUSTOM_DIR"

  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  WoslandOS x86 ISO built successfully! 🎉          ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  📦 ISO : ${YELLOW}${FINAL_ISO}${NC}  ($(du -sh "$FINAL_ISO" | cut -f1))"
  echo ""
  echo -e "  Flash to USB:  ${YELLOW}sudo dd if=${FINAL_ISO} of=/dev/sdX bs=4M status=progress${NC}"
  echo -e "  Or use Rufus / Ventoy on Windows"
  echo -e "  Proxmox VM:    Upload to Proxmox ISO storage and create a VM"
  echo ""
}

main() {
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║     WoslandOS x86 ISO Builder                     ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  check_deps
  download_iso "${1:-}"
  extract_iso
  inject_autoinstall
  patch_grub
  build_iso
}

main "$@"
