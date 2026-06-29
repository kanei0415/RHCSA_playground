#!/bin/bash
# [node1] 問題2: ユーザーとグループの管理 (idempotent)
set -euo pipefail

PASS="password"

echo ">>> Creating group: developer (GID 60000)"
if getent group developer &>/dev/null; then
  echo "    group exists — skipping"
else
  groupadd -g 60000 developer
fi

echo ">>> Creating user01 (developer group, bash)"
if id user01 &>/dev/null; then
  usermod -G developer -s /bin/bash user01
else
  useradd -m -G developer -s /bin/bash user01
fi
echo "${PASS}" | passwd --stdin user01

echo ">>> Creating user02 (developer group, bash)"
if id user02 &>/dev/null; then
  usermod -G developer -s /bin/bash user02
else
  useradd -m -G developer -s /bin/bash user02
fi
echo "${PASS}" | passwd --stdin user02

echo ">>> Creating user03 (nologin)"
if id user03 &>/dev/null; then
  usermod -s /sbin/nologin user03
else
  useradd -m -s /sbin/nologin user03
fi
echo "${PASS}" | passwd --stdin user03

echo ">>> Creating user04 (UID 3000, bash)"
if id user04 &>/dev/null; then
  # UID 変更は usermod -u (ホームディレクトリのファイル所有者も変更)
  CURRENT_UID=$(id -u user04)
  if [ "${CURRENT_UID}" != "3000" ]; then
    usermod -u 3000 user04
  fi
  usermod -s /bin/bash user04
else
  useradd -m -u 3000 -s /bin/bash user04
fi
echo "${PASS}" | passwd --stdin user04

echo ">>> Verify:"
getent group developer
id user01; id user02; id user03; id user04
