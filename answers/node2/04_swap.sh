#!/bin/bash
# [node2] 問題4: SWAP 追加 — /dev/sdc に 1GB スワップパーティション (idempotent)
set -euo pipefail

# ── ディスク検出 (2番目の追加ディスク) ───────────────────────────
ROOT_DISK=$(lsblk -ndo NAME,MOUNTPOINTS 2>/dev/null | awk '$2=="/"{print $1}' | \
            sed 's/[0-9]*$//' | head -1)
if [ -z "${ROOT_DISK}" ]; then
  ROOT_DISK=$(df / | awk 'NR==2{print $1}' | sed 's|/dev/||' | sed 's/[0-9p]*$//')
fi

# LVM が使用しているディスクを除外
LVM_DISKS=$(pvs --noheadings -o pv_name 2>/dev/null | tr -d ' ' | sed 's|/dev/||' | sed 's/[0-9p]*$//')

SWAP_DISK=""
while IFS= read -r DEV; do
  [ "${DEV}" = "${ROOT_DISK}" ] && continue
  echo "${LVM_DISKS}" | grep -q "^${DEV}$" && continue
  SWAP_DISK="${DEV}"
  break
done < <(lsblk -nd -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')

if [ -z "${SWAP_DISK}" ]; then
  echo "ERROR: スワップ用ディスクが見つかりません"
  lsblk
  exit 1
fi
DISK="/dev/${SWAP_DISK}"
PART="${DISK}1"
echo ">>> Using disk: ${DISK}  partition: ${PART}"

# ── パーティション作成 ─────────────────────────────────────────────
if lsblk "${DISK}" 2>/dev/null | grep -q "part\|${SWAP_DISK}1"; then
  echo ">>> Partition ${PART} already exists — skipping fdisk"
else
  echo ">>> Creating swap partition with fdisk"
  fdisk "${DISK}" << 'EOF'
n
p
1


+1G
t
82
w
EOF
  sleep 1
  partprobe "${DISK}" 2>/dev/null || true
  udevadm settle 2>/dev/null || true
fi

# ── mkswap ────────────────────────────────────────────────────────
if blkid "${PART}" 2>/dev/null | grep -q "swap"; then
  echo ">>> ${PART} already formatted as swap — skipping mkswap"
else
  echo ">>> mkswap ${PART}"
  mkswap "${PART}"
fi

# ── swapon ────────────────────────────────────────────────────────
if swapon --show | grep -q "${PART}"; then
  echo ">>> ${PART} already active — skipping swapon"
else
  echo ">>> swapon ${PART}"
  swapon "${PART}"
fi

# ── /etc/fstab ────────────────────────────────────────────────────
if grep -q "${PART}" /etc/fstab; then
  echo ">>> /etc/fstab already has ${PART} — skipping"
else
  echo ">>> Adding to /etc/fstab: ${PART} swap swap defaults 0 0"
  echo "${PART} swap swap defaults 0 0" >> /etc/fstab
fi

echo ">>> Verify:"
swapon --show
grep swap /etc/fstab
