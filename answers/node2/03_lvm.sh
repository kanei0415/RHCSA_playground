#!/bin/bash
# [node2] 問題3: LVM 構成 (idempotent)
# vg_data (PE=16MB) / lv_web 2GB XFS on /dev/sdb → /web → extend to 3GB
set -euo pipefail

# ── ディスク検出 ──────────────────────────────────────────────────
# ブートディスクを除く最初の追加ディスクを検出
ROOT_DISK=$(lsblk -ndo NAME,MOUNTPOINTS 2>/dev/null | awk '$2=="/"{print $1}' | \
            sed 's/[0-9]*$//' | head -1)
if [ -z "${ROOT_DISK}" ]; then
  ROOT_DISK=$(df / | awk 'NR==2{print $1}' | sed 's|/dev/||' | sed 's/[0-9p]*$//')
fi

EXTRA_DISK=$(lsblk -nd -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}' | \
             grep -v "^${ROOT_DISK}$" | head -1)

if [ -z "${EXTRA_DISK}" ]; then
  echo "ERROR: 追加ディスクが見つかりません (lsblk):"
  lsblk
  exit 1
fi
DISK="/dev/${EXTRA_DISK}"
echo ">>> Using disk: ${DISK}"

# ── PV ────────────────────────────────────────────────────────────
if pvs "${DISK}" &>/dev/null; then
  echo ">>> PV ${DISK} already exists — skipping pvcreate"
else
  echo ">>> pvcreate ${DISK}"
  pvcreate "${DISK}"
fi

# ── VG ────────────────────────────────────────────────────────────
if vgs vg_data &>/dev/null; then
  echo ">>> VG vg_data already exists — skipping vgcreate"
else
  echo ">>> vgcreate -s 16M vg_data ${DISK}"
  vgcreate -s 16M vg_data "${DISK}"
fi

# ── LV (初期 2GB) ─────────────────────────────────────────────────
if lvs vg_data/lv_web &>/dev/null; then
  echo ">>> LV lv_web already exists — skipping lvcreate"
else
  echo ">>> lvcreate -L 2G -n lv_web vg_data"
  lvcreate -L 2G -n lv_web vg_data
fi

# ── XFS フォーマット ──────────────────────────────────────────────
if blkid /dev/vg_data/lv_web 2>/dev/null | grep -q "xfs"; then
  echo ">>> lv_web already formatted as XFS — skipping mkfs"
else
  echo ">>> mkfs.xfs /dev/vg_data/lv_web"
  mkfs.xfs /dev/vg_data/lv_web
fi

# ── マウント ──────────────────────────────────────────────────────
mkdir -p /web

FSTAB_ENTRY="/dev/vg_data/lv_web /web xfs defaults 0 0"
if grep -q "/web" /etc/fstab; then
  echo ">>> /etc/fstab already has /web entry — skipping"
else
  echo ">>> Adding to /etc/fstab: ${FSTAB_ENTRY}"
  echo "${FSTAB_ENTRY}" >> /etc/fstab
fi

if mountpoint -q /web; then
  echo ">>> /web already mounted"
else
  echo ">>> mount -a"
  mount -a
fi

# ── LV 拡張 3GB ──────────────────────────────────────────────────
CURRENT_GB=$(lvs --noheadings --units g -o lv_size vg_data/lv_web 2>/dev/null | tr -d ' <g')
CURRENT_INT=${CURRENT_GB%%.*}
if [ "${CURRENT_INT:-0}" -ge 3 ]; then
  echo ">>> lv_web already >= 3GB (${CURRENT_GB}G) — skipping lvextend"
else
  echo ">>> lvextend -L 3G /dev/vg_data/lv_web"
  lvextend -L 3G /dev/vg_data/lv_web
  echo ">>> xfs_growfs /web (online resize)"
  xfs_growfs /web
fi

echo ">>> Verify:"
vgs vg_data
lvs vg_data/lv_web
df -hT /web
