#!/bin/bash
# node2 Bootstrap — RHCSA Simulator
# State: root password RANDOMIZED (unknown), NIC configured, NFS server, extra disks
set -euo pipefail

TESTER_USER="${TESTER_USER:-tester}"
TESTER_PASS="${TESTER_PASS:-testpass}"
NODE2_IP="${NODE2_IP:-192.168.56.102}"
NODE1_IP="${NODE1_IP:-192.168.56.101}"

log() { echo "[node2-bootstrap] $*"; }

log "=== node2 Bootstrap Start ==="

# ── Root password: RANDOMIZE (exam task: recover via rd.break) ────────────
log "Randomizing root password (exam: recover via bootloader rescue)..."
RAND_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)
echo "${RAND_PASS}" | passwd --stdin root
# Root password is intentionally unrecoverable here — exam task

# ── Tester user (SSH access, sudo) ────────────────────────────────────────
log "Creating tester user..."
if ! id "${TESTER_USER}" &>/dev/null; then
  useradd -m -c "RHCSA Tester" "${TESTER_USER}"
fi
echo "${TESTER_PASS}" | passwd --stdin "${TESTER_USER}"
usermod -aG wheel "${TESTER_USER}"
echo "${TESTER_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

# ── SSH: allow password auth, disable root login ──────────────────────────
log "Configuring sshd..."
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
systemctl restart sshd

# ── DNF repo ──────────────────────────────────────────────────────────────
log "Enabling DNF repos..."
dnf config-manager --set-enabled baseos appstream extras 2>/dev/null || true

# ── Base packages ─────────────────────────────────────────────────────────
log "Installing base packages..."
dnf -y install \
  vim bash-completion net-tools bind-utils \
  nfs-utils rpcbind \
  lvm2 \
  podman container-tools \
  policycoreutils-python-utils \
  2>/dev/null || true

# ── Configure exam NIC ────────────────────────────────────────────────────
log "Configuring exam network interface..."
FIRST_NIC=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ":ethernet" | head -1 | cut -d: -f1)
EXAM_NIC=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ":ethernet" | grep -v "^${FIRST_NIC}:" | head -1 | cut -d: -f1)

if [ -n "${EXAM_NIC}" ]; then
  # Remove any existing connection for this NIC
  EXISTING=$(nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep ":${EXAM_NIC}$" | cut -d: -f1)
  [ -n "${EXISTING}" ] && nmcli con delete "${EXISTING}" 2>/dev/null || true

  nmcli con add type ethernet con-name "exam-net" ifname "${EXAM_NIC}" \
    ipv4.addresses "${NODE2_IP}/24" \
    ipv4.method manual \
    connection.autoconnect yes
  nmcli con up exam-net
  log "Exam NIC ${EXAM_NIC} configured: ${NODE2_IP}/24"
else
  log "WARN: Second NIC not found"
fi

# ── /etc/hosts ────────────────────────────────────────────────────────────
grep -q "node2.example.com" /etc/hosts || \
  echo "127.0.0.1 node2.example.com node2" >> /etc/hosts
grep -q "node1.example.com" /etc/hosts || \
  echo "${NODE1_IP} node1.example.com node1" >> /etc/hosts

# ── NFS Server (node1 autofs exam mounts from here) ──────────────────────
log "Setting up NFS server for node1 autofs exam..."
mkdir -p /exports/data
echo "This is node2 NFS export — autofs exam data" > /exports/data/README.txt
chown -R nobody:nobody /exports/data

# Configure exports
cat > /etc/exports << 'EOF'
/exports/data 192.168.56.0/24(rw,sync,no_root_squash)
EOF

systemctl enable --now rpcbind nfs-server
exportfs -r

# Firewall: allow NFS
firewall-cmd --permanent \
  --add-service=nfs \
  --add-service=rpc-bind \
  --add-service=mountd 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

log "NFS: /exports/data exported to 192.168.56.0/24"

log ""
log "=== node2 Bootstrap Complete ==="
log "  Root password : UNKNOWN (randomized) → exam: use rd.break to recover"
log "  Tester user   : ${TESTER_USER} / ${TESTER_PASS}"
log "  Exam NIC      : ${EXAM_NIC:-ens36} → ${NODE2_IP}"
log "  NFS export    : /exports/data (for node1 autofs)"
log "  Extra disks   : check with 'lsblk' after boot (sdb=5GB, sdc=3GB)"
