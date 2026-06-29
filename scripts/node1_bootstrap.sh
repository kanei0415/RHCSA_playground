#!/bin/bash
# node1 Bootstrap — RHCSA Simulator
# State: root password KNOWN, second NIC NOT configured (exam task)
set -euo pipefail

TESTER_USER="${TESTER_USER:-tester}"
TESTER_PASS="${TESTER_PASS:-testpass}"
ROOT_PASS="${ROOT_PASS:-redhat}"
NODE2_IP="${NODE2_IP:-192.168.56.102}"

log() { echo "[node1-bootstrap] $*"; }

log "=== node1 Bootstrap Start ==="

# ── Root password (known: students use 'su -' with this) ──────────────────
log "Setting root password to: ${ROOT_PASS}"
echo "${ROOT_PASS}" | passwd --stdin root

# ── Tester user (SSH access, sudo) ────────────────────────────────────────
log "Creating tester user..."
if ! id "${TESTER_USER}" &>/dev/null; then
  useradd -m -c "RHCSA Tester" "${TESTER_USER}"
fi
echo "${TESTER_PASS}" | passwd --stdin "${TESTER_USER}"
usermod -aG wheel "${TESTER_USER}"
echo "${TESTER_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

# ── SSH: allow password auth, disable root login ───────────────────────────
log "Configuring sshd..."
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
systemctl restart sshd

# ── DNF repo (AlmaLinux built-in repos via NAT) ───────────────────────────
log "Enabling DNF repos..."
dnf config-manager --set-enabled baseos appstream extras 2>/dev/null || true

# ── Base packages ─────────────────────────────────────────────────────────
log "Installing base packages..."
dnf -y install \
  vim bash-completion net-tools bind-utils \
  nfs-utils autofs \
  tar gzip bzip2 xz \
  policycoreutils-python-utils \
  2>/dev/null || true

# ── /etc/hosts ────────────────────────────────────────────────────────────
grep -q "node2.example.com" /etc/hosts || \
  echo "${NODE2_IP} node2.example.com node2" >> /etc/hosts
grep -q "node1.example.com" /etc/hosts || \
  echo "127.0.0.1 node1.example.com node1" >> /etc/hosts

# ── Exam NIC: ensure the second NIC is DISCONNECTED (exam task) ───────────
log "Ensuring second NIC (exam task) is NOT configured..."
# Detect second ethernet (not first NAT NIC)
FIRST_NIC=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ":ethernet" | head -1 | cut -d: -f1)
EXAM_NIC=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ":ethernet" | grep -v "^${FIRST_NIC}:" | head -1 | cut -d: -f1)

if [ -n "${EXAM_NIC}" ]; then
  # Delete any auto-created connection for this NIC
  nmcli con show | awk '{print $1}' | while read CON; do
    DEV=$(nmcli -t -f connection.interface-name con show "${CON}" 2>/dev/null | cut -d: -f2)
    if [ "${DEV}" = "${EXAM_NIC}" ]; then
      nmcli con delete "${CON}" 2>/dev/null || true
    fi
  done
  nmcli dev disconnect "${EXAM_NIC}" 2>/dev/null || true
  log "Exam NIC ${EXAM_NIC} is disconnected (correct exam state)"
else
  log "WARN: Second NIC not found — it may appear after reboot"
fi

log ""
log "=== node1 Bootstrap Complete ==="
log "  Root password : ${ROOT_PASS}"
log "  Tester user   : ${TESTER_USER} / ${TESTER_PASS}"
log "  Exam NIC      : ${EXAM_NIC:-ens36} — NOT configured (student must configure)"
log "  node2 host    : ${NODE2_IP}"
