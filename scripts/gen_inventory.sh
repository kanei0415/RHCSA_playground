#!/bin/bash
# Generate ansible/inventory.ini from vagrant ssh-config
set -euo pipefail

INVENTORY="ansible/inventory.ini"
mkdir -p ansible

get_val() {
  local vm="$1" key="$2"
  vagrant ssh-config "${vm}" 2>/dev/null | awk "/^  ${key} /{print \$2}"
}

log() { echo "[gen_inventory] $*"; }

log "Reading vagrant ssh-config..."

N1_HOST=$(get_val node1 HostName)
N1_PORT=$(get_val node1 Port)
N1_KEY=$(get_val node1 IdentityFile)

N2_HOST=$(get_val node2 HostName)
N2_PORT=$(get_val node2 Port)
N2_KEY=$(get_val node2 IdentityFile)

cat > "${INVENTORY}" << EOF
[node1]
node1 ansible_host=${N1_HOST:-127.0.0.1} ansible_port=${N1_PORT:-2222} ansible_user=tester ansible_ssh_private_key_file=${N1_KEY}

[node2]
node2 ansible_host=${N2_HOST:-127.0.0.1} ansible_port=${N2_PORT:-2200} ansible_user=tester ansible_ssh_private_key_file=${N2_KEY}

[all:vars]
ansible_become=true
ansible_become_method=sudo
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

log "Generated: ${INVENTORY}"
cat "${INVENTORY}"
