#!/bin/bash
# [node2] 問題2: DNF リポジトリ設定 (idempotent)
# 試験想定: http://192.168.56.100/{baseos,appstream} を登録
# シミュレーター: 実際に動くAlmaLinux vaultリポジトリで代替
set -euo pipefail

ARCH=$(uname -m)

echo ">>> Removing all existing repo files"
rm -f /etc/yum.repos.d/*.repo

echo ">>> Cleaning DNF cache"
dnf clean all 2>/dev/null || true

# ---- 試験本番の答え (サーバーが 192.168.56.100 にある前提) ----
# dnf config-manager --add-repo=http://192.168.56.100/baseos
# echo 'gpgcheck=0' >> /etc/yum.repos.d/192.168.56.100_baseos.repo
# dnf config-manager --add-repo=http://192.168.56.100/appstream
# echo 'gpgcheck=0' >> /etc/yum.repos.d/192.168.56.100_appstream.repo

# ---- シミュレーター代替: AlmaLinux vault (実際に動作) ----
echo ">>> Writing baseos.repo (AlmaLinux vault — simulator substitute)"
cat > /etc/yum.repos.d/baseos.repo << EOF
[baseos]
name=AlmaLinux 9 - BaseOS
baseurl=https://repo.almalinux.org/vault/9/BaseOS/${ARCH}/os/
enabled=1
gpgcheck=0
EOF

cat > /etc/yum.repos.d/appstream.repo << EOF
[appstream]
name=AlmaLinux 9 - AppStream
baseurl=https://repo.almalinux.org/vault/9/AppStream/${ARCH}/os/
enabled=1
gpgcheck=0
EOF

echo ">>> Verify — dnf repolist:"
dnf repolist 2>/dev/null

echo ">>> Test install (telnet):"
dnf -y install telnet 2>/dev/null && echo "telnet install: OK" || echo "telnet install: FAILED (network?)"
