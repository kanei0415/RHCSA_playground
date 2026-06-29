#!/bin/bash
# [node1] 問題3: ファイル権限 (idempotent)
# /data/developer: setgid + rwxrwx--- (developer group only)
# /data/shared:    sticky bit + rwxrwxrwx (everyone, own-delete only)
# ACL: user04 has read on /data/developer
set -euo pipefail

echo ">>> Creating directories"
mkdir -p /data/developer /data/shared

echo ">>> /data/developer: group=developer, chmod 2770 (setgid + rwxrwx---)"
chown root:developer /data/developer
chmod 2770 /data/developer

echo ">>> /data/shared: chmod 1777 (sticky + rwxrwxrwx)"
chown root:root /data/shared
chmod 1777 /data/shared

echo ">>> ACL: user04 gets read on /data/developer"
# setfacl -m は idempotent (再実行しても同じ結果)
setfacl -m u:user04:r /data/developer

echo ">>> Verify:"
ls -ld /data/developer /data/shared
getfacl /data/developer
