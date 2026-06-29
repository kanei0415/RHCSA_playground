#!/bin/bash
# [node1] 問題1: ネットワーク設定
# ens36 を 192.168.56.101/24 で静的設定する (idempotent)
set -euo pipefail

EXAM_IP="192.168.56.101/24"
CON_NAME="exam-net"

# 第2 Ethernet NIC を検出 (NAT の NIC 以外)
FIRST_NIC=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="ethernet"{print $1; exit}')
EXAM_NIC=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: -v first="${FIRST_NIC}" \
  '$2=="ethernet" && $1!=first {print $1; exit}')
EXAM_NIC="${EXAM_NIC:-ens36}"

echo ">>> Exam NIC detected: ${EXAM_NIC}"

# 既存の接続を削除 (idempotent: 存在すれば削除、なければスキップ)
while IFS= read -r CON; do
  DEV=$(nmcli -t -f connection.interface-name con show "${CON}" 2>/dev/null | cut -d: -f2)
  if [ "${DEV}" = "${EXAM_NIC}" ]; then
    echo ">>> Removing existing connection: ${CON}"
    nmcli con delete "${CON}" 2>/dev/null || true
  fi
done < <(nmcli -t -f NAME con show 2>/dev/null)

# 新規接続を作成・有効化
nmcli con add \
  type ethernet \
  con-name "${CON_NAME}" \
  ifname "${EXAM_NIC}" \
  ipv4.addresses "${EXAM_IP}" \
  ipv4.method manual \
  connection.autoconnect yes

nmcli con up "${CON_NAME}"

echo ">>> Result:"
ip addr show "${EXAM_NIC}"
