#!/bin/bash
# [node1] 問題4: autofs — node2:/exports/data を /mnt/remote/data に自動マウント (idempotent)
set -euo pipefail

NODE2_IP="192.168.56.102"
NFS_EXPORT="/exports/data"
MOUNT_BASE="/mnt/remote"
MAP_KEY="data"
MASTER_FILE="/etc/auto.master.d/remote.autofs"
MAP_FILE="/etc/auto.remote"

echo ">>> Installing autofs and nfs-utils"
dnf -y install autofs nfs-utils 2>/dev/null || true

echo ">>> Creating mount base: ${MOUNT_BASE}"
mkdir -p "${MOUNT_BASE}"

echo ">>> Writing autofs master map: ${MASTER_FILE}"
cat > "${MASTER_FILE}" << EOF
${MOUNT_BASE}  ${MAP_FILE}
EOF

echo ">>> Writing autofs map: ${MAP_FILE}"
cat > "${MAP_FILE}" << EOF
${MAP_KEY}  -rw,sync  ${NODE2_IP}:${NFS_EXPORT}
EOF

echo ">>> Enabling and restarting autofs"
systemctl enable autofs
systemctl restart autofs

echo ">>> Triggering mount by access"
ls "${MOUNT_BASE}/${MAP_KEY}" && echo "Mount OK" || echo "Mount FAILED — check NFS server on node2"
