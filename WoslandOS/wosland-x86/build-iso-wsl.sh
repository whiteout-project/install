#!/usr/bin/env bash
# ============================================================
# WoslandOS x86 -- ISO Builder (WSL / Windows-friendly)
#
# Requirements (install once in WSL):
#   sudo apt update
#   sudo apt install xorriso wget openssl p7zip-full python3
#
# Usage:
#   ./build-iso.sh           -- build with current config.sh
#   ./build-iso.sh --clean   -- remove cached base ISO first
#
# WSL changes vs native Linux version:
#   - EFI partition extracted via Python struct instead of
#     dd+fdisk (fdisk -l on .iso files is unreliable in WSL2)
#   - Cleanup trap skips umount (no loop mounts used)
#   - Output flash instructions show Windows-friendly tools
#     (Rufus / balenaEtcher) instead of dd
#   - All paths quoted throughout to handle Windows-style
#     paths with spaces (e.g. /mnt/c/Users/My Name/...)
#   - Auto-detects WSL vs native Linux and adjusts accordingly
#   - deps check includes python3
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

# Detect WSL
IS_WSL=0
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  IS_WSL=1
  info "Running inside WSL — using WSL-compatible code paths."
fi

# No umount needed — we use 7z extraction, not loop mounts
cleanup() { :; }
trap cleanup EXIT

check_deps() {
  info "Checking dependencies..."

  # Root not required in WSL for ISO building (no loop mounts)
  if [ "$IS_WSL" -eq 0 ] && [ "$EUID" -ne 0 ]; then
    error "Run as root on native Linux: sudo ./build-iso.sh"
  fi
  if [ "$IS_WSL" -eq 1 ] && [ "$EUID" -ne 0 ]; then
    warn "Not running as root. Some steps may fail if permissions are needed."
    warn "If you hit errors, retry with: sudo ./build-iso-wsl.sh"
  fi

  for cmd in xorriso wget openssl 7z python3; do
    command -v "$cmd" &>/dev/null || \
      error "Missing: $cmd\n  Run: sudo apt install xorriso wget openssl p7zip-full python3"
  done
}

download_iso() {
  mkdir -p "${SCRIPT_DIR}/build-tmp" "${OUTPUT_DIR}"
  if [ "${1:-}" = "--clean" ] && [ -f "${BASE_ISO}" ]; then
    info "Removing cached ISO..."
    rm -f "${BASE_ISO}"
  fi
  if [ ! -f "${BASE_ISO}" ]; then
    UBUNTU_ISO_URL=$(resolve_ubuntu_iso_url)
    info "Downloading ${UBUNTU_ISO_URL##*/}..."
    wget --show-progress -O "${BASE_ISO}" "${UBUNTU_ISO_URL}"
  else
    info "Using cached base ISO."
  fi
}

extract_iso() {
  info "Extracting base ISO..."
  rm -rf "${CUSTOM_DIR}"
  mkdir -p "${CUSTOM_DIR}"

  info "Extracting with 7z..."
  7z x "${BASE_ISO}" -o"${CUSTOM_DIR}" -y > /dev/null

  chmod -R u+w "${CUSTOM_DIR}"
  info "ISO extracted: $(du -sh "${CUSTOM_DIR}" | cut -f1)"
}

inject_autoinstall() {
  info "Injecting autoinstall configuration..."

  PW_HASH=$(echo -n "${OS_PASSWORD}" | openssl passwd -6 -stdin)

  mkdir -p "${CUSTOM_DIR}/autoinstall"
  USERDATA_DST="${CUSTOM_DIR}/autoinstall/user-data"
  METADATA_DST="${CUSTOM_DIR}/autoinstall/meta-data"

  sed \
    -e "s|@@OS_USERNAME@@|${OS_USERNAME}|g" \
    -e "s|@@OS_PASSWORD_HASH@@|${PW_HASH}|g" \
    -e "s|@@OS_HOSTNAME@@|${OS_HOSTNAME}|g" \
    -e "s|@@WEBSERVER_DIR@@|${WEBSERVER_DIR}|g" \
    "${SCRIPT_DIR}/iso-builder/user-data" > "${USERDATA_DST}"

  sed -e "s|@@OS_HOSTNAME@@|${OS_HOSTNAME}|g" \
    "${SCRIPT_DIR}/iso-builder/meta-data" > "${METADATA_DST}"

  PAYLOAD_DIR="${CUSTOM_DIR}/wosland"
  mkdir -p "${PAYLOAD_DIR}"

  sed \
    -e "s|@@OS_USERNAME@@|${OS_USERNAME}|g" \
    -e "s|@@OS_PASSWORD@@|${OS_PASSWORD}|g" \
    -e "s|@@OS_HOSTNAME@@|${OS_HOSTNAME}|g" \
    -e "s|@@BOT_MAIN_PY@@|${BOT_MAIN_PY}|g" \
    -e "s|@@BOT_INSTALL_PY@@|${BOT_INSTALL_PY}|g" \
    -e "s|@@BOT_JS_REPO@@|${BOT_JS_REPO}|g" \
    -e "s|@@BOT_JS_BRANCH@@|${BOT_JS_BRANCH}|g" \
    -e "s|@@BOT_KINGSHOT_REPO@@|${BOT_KINGSHOT_REPO}|g" \
    -e "s|@@BOT_KINGSHOT_BRANCH@@|${BOT_KINGSHOT_BRANCH}|g" \
    -e "s|@@DEFAULT_BOT@@|${DEFAULT_BOT}|g" \
    -e "s|@@BACKGROUND_IMAGE_URL@@|${BACKGROUND_IMAGE_URL}|g" \
    -e "s|@@DESKTOP@@|${DESKTOP}|g" \
    -e "s|@@BOT_DIR@@|${BOT_DIR}|g" \
    -e "s|@@VENV_DIR@@|${VENV_DIR}|g" \
    -e "s|@@SERVICE_NAME@@|${SERVICE_NAME}|g" \
    -e "s|@@TOKEN_FILE@@|${TOKEN_FILE}|g" \
    -e "s|@@WEBSERVER_DIR@@|${WEBSERVER_DIR}|g" \
    -e "s|@@WEBSERVER_PORT@@|${WEBSERVER_PORT}|g" \
    "${SCRIPT_DIR}/rootfs-overlay/usr/local/bin/wosland-provision.sh" \
    > "${PAYLOAD_DIR}/wosland-provision.sh"
  chmod +x "${PAYLOAD_DIR}/wosland-provision.sh"

  # ── FIX: Substitute and copy wosland-switch-bot.sh ─────────
  # Was missing from the original WSL build script, causing
  # wosland-provision.sh step 13 to fail with "No such file"
  # when trying to chmod +x /usr/local/bin/wosland-switch-bot.sh
  sed \
    -e "s|@@OS_USERNAME@@|${OS_USERNAME}|g" \
    -e "s|@@BOT_DIR@@|${BOT_DIR}|g" \
    -e "s|@@SERVICE_NAME@@|${SERVICE_NAME}|g" \
    -e "s|@@TOKEN_FILE@@|${TOKEN_FILE}|g" \
    -e "s|@@BOT_MAIN_PY@@|${BOT_MAIN_PY}|g" \
    -e "s|@@BOT_INSTALL_PY@@|${BOT_INSTALL_PY}|g" \
    -e "s|@@BOT_JS_REPO@@|${BOT_JS_REPO}|g" \
    -e "s|@@BOT_JS_BRANCH@@|${BOT_JS_BRANCH}|g" \
    -e "s|@@BOT_KINGSHOT_REPO@@|${BOT_KINGSHOT_REPO}|g" \
    -e "s|@@BOT_KINGSHOT_BRANCH@@|${BOT_KINGSHOT_BRANCH}|g" \
    "${SCRIPT_DIR}/rootfs-overlay/usr/local/bin/wosland-switch-bot.sh" \
    > "${PAYLOAD_DIR}/wosland-switch-bot.sh"
  chmod +x "${PAYLOAD_DIR}/wosland-switch-bot.sh"

  # ── Strip CRLF from all injected scripts ─────────────────
  # Prevents 'bash\r: No such file' errors when scripts were
  # edited or generated on Windows before being built in WSL.
  find "${PAYLOAD_DIR}" -name "*.sh" -exec sed -i 's/\r//' {} + 2>/dev/null || true
  find "${CUSTOM_DIR}/autoinstall" -type f -exec sed -i 's/\r//' {} + 2>/dev/null || true

  cp "${SCRIPT_DIR}/webserver/app.py"                                          "${PAYLOAD_DIR}/app.py"
  cp "${SCRIPT_DIR}/rootfs-overlay/etc/systemd/system/wosland-firstboot.service" \
     "${PAYLOAD_DIR}/wosland-firstboot.service"
}

patch_grub() {
  info "Patching GRUB to boot autoinstall automatically..."

  GRUB_CFG="${CUSTOM_DIR}/boot/grub/grub.cfg"
  [ -f "${GRUB_CFG}" ] || GRUB_CFG="${CUSTOM_DIR}/grub/grub.cfg"
  [ -f "${GRUB_CFG}" ] || error "Could not find grub.cfg in extracted ISO."

  AUTOINSTALL_ENTRY='
set default="0"
set timeout=5

menuentry "WoslandOS -- Automated Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall "ds=nocloud;s=/cdrom/autoinstall/" ---
    initrd  /casper/initrd
}
'
  cp "${GRUB_CFG}" "${GRUB_CFG}.orig"
  echo "${AUTOINSTALL_ENTRY}" | cat - "${GRUB_CFG}" > /tmp/grub_new.cfg
  mv /tmp/grub_new.cfg "${GRUB_CFG}"
}

# ── EFI extraction (WSL-safe) ────────────────────────────────
# The original used dd+fdisk to extract the EFI partition from
# the base ISO. fdisk -l on a .iso file is unreliable in WSL2
# because WSL doesn't expose loop devices the same way.
# Instead we use a small Python script to read the ISO 9660 /
# GPT partition table directly from the file — no root or loop
# mount needed, works identically on WSL and native Linux.
extract_efi_partition() {
  local iso="$1"
  local out="$2"

  info "Extracting EFI partition using Python (WSL-safe)..."

  python3 - "${iso}" "${out}" <<'PYEOF'
import sys, struct

iso_path = sys.argv[1]
out_path  = sys.argv[2]

SECTOR = 512

with open(iso_path, 'rb') as f:
    # Read the protective MBR (sector 0) to find GPT header at sector 1
    f.seek(SECTOR)
    gpt_header = f.read(92)

    sig = gpt_header[:8]
    if sig != b'EFI PART':
        print("  No GPT found in ISO — skipping EFI extraction.", file=sys.stderr)
        sys.exit(0)

    # GPT header: partition entry LBA at offset 72, count at 80, size at 84
    part_entry_lba  = struct.unpack_from('<Q', gpt_header, 72)[0]
    part_count      = struct.unpack_from('<I', gpt_header, 80)[0]
    part_entry_size = struct.unpack_from('<I', gpt_header, 84)[0]

    f.seek(part_entry_lba * SECTOR)
    efi_start = None
    efi_size  = None

    EFI_GUID = b'\x28\x73\x2a\xc1\x1f\xf8\xd2\x11\xba\x4b\x00\xa0\xc9\x3e\xc9\x3b'

    for i in range(part_count):
        entry = f.read(part_entry_size)
        if len(entry) < 48:
            break
        type_guid = entry[0:16]
        if type_guid == EFI_GUID:
            start_lba = struct.unpack_from('<Q', entry, 32)[0]
            end_lba   = struct.unpack_from('<Q', entry, 40)[0]
            efi_start = start_lba
            efi_size  = end_lba - start_lba + 1
            break

    if efi_start is None:
        print("  No EFI System Partition found in GPT — skipping.", file=sys.stderr)
        sys.exit(0)

    f.seek(efi_start * SECTOR)
    data = f.read(efi_size * SECTOR)

with open(out_path, 'wb') as f:
    f.write(data)

print(f"  EFI partition: {efi_size} sectors ({efi_size * SECTOR // 1024} KB) -> {out_path}")
PYEOF
}

build_iso() {
  info "Building final ISO with xorriso..."
  mkdir -p "${OUTPUT_DIR}"

  MBR_IMG="${WORK_DIR}/mbr.img"
  EFI_IMG="${WORK_DIR}/efi.img"

  # Extract MBR bootstrap code (first 432 bytes of base ISO)
  dd if="${BASE_ISO}" bs=1 count=432 of="${MBR_IMG}" 2>/dev/null

  # Extract EFI partition using Python (WSL-safe, no fdisk needed)
  extract_efi_partition "${BASE_ISO}" "${EFI_IMG}"

  if [ -f "${EFI_IMG}" ] && [ -s "${EFI_IMG}" ]; then
    info "Building hybrid BIOS+UEFI ISO..."
    xorriso -as mkisofs \
      -r -V "WoslandOS_x86" \
      -o "${FINAL_ISO}" \
      --grub2-mbr "${MBR_IMG}" \
      -partition_offset 16 \
      --mbr-force-bootable \
      -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "${EFI_IMG}" \
      -appended_part_as_gpt \
      -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
      -c '/boot.catalog' \
      -b '/boot/grub/i386-pc/eltorito.img' \
        -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
      -eltorito-alt-boot \
      -e '--interval:appended_partition_2:::' \
        -no-emul-boot \
      "${CUSTOM_DIR}" 2>/dev/null
  else
    warn "No EFI partition found — building BIOS-only ISO (will not boot on UEFI systems without CSM)."
    xorriso -as mkisofs \
      -r -V "WoslandOS_x86" \
      -o "${FINAL_ISO}" \
      -b isolinux/isolinux.bin \
      -c isolinux/boot.cat \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
      "${CUSTOM_DIR}"
  fi

  # ── Windows-friendly flash instructions ─────────────────────
  # On WSL, dd to /dev/sdX won't reach physical USB drives.
  # Use Rufus or balenaEtcher from Windows instead.
  local WIN_ISO_PATH=""
  if [ "$IS_WSL" -eq 1 ]; then
    # Convert WSL path to Windows path for user convenience
    WIN_ISO_PATH=$(wslpath -w "${FINAL_ISO}" 2>/dev/null || echo "${FINAL_ISO}")
  fi

  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  WoslandOS x86 ISO built successfully!            ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ISO  : ${YELLOW}${FINAL_ISO}${NC}  ($(du -sh "${FINAL_ISO}" | cut -f1))"
  echo ""

  if [ "$IS_WSL" -eq 1 ]; then
    echo -e "  ${GREEN}Flash to USB from Windows:${NC}"
    echo -e "    Rufus       : https://rufus.ie  (recommended)"
    echo -e "    balenaEtcher: https://etcher.balena.io"
    if [ -n "$WIN_ISO_PATH" ]; then
      echo -e "    Windows path: ${YELLOW}${WIN_ISO_PATH}${NC}"
    fi
    echo ""
    echo -e "  ${GREEN}Flash to USB from WSL (if /dev/sdX is visible):${NC}"
    echo -e "    ${YELLOW}sudo dd if=\"${FINAL_ISO}\" of=/dev/sdX bs=4M status=progress${NC}"
  else
    echo -e "  Flash: ${YELLOW}sudo dd if=\"${FINAL_ISO}\" of=/dev/sdX bs=4M status=progress${NC}"
  fi
  echo ""
}

main() {
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║     WoslandOS x86 ISO Builder (WSL-friendly)      ║${NC}"
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