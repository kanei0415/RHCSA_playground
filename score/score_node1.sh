#!/bin/bash
# RHCSA Simulator — node1 採点スクリプト
# Usage: bash score/score_node1.sh

set -uo pipefail

PASS=0; FAIL=0; SKIP=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[PASS]${NC} $*"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; ((FAIL++)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; ((SKIP++)); }

# Run command on node1 as root
n1() { vagrant ssh node1 -- sudo bash -c "$*" 2>/dev/null | tr -d '\r'; }

echo "============================================================"
echo " RHCSA Simulator — node1 採点"
echo "============================================================"

# ── ネットワーク設定 ─────────────────────────────────────────────
echo ""
echo "【ネットワーク設定】"

if n1 "ip addr" | grep -q "192.168.56.101"; then
  ok "192.168.56.101 がアサインされている"
else
  fail "192.168.56.101 が設定されていない"
fi

ACTIVE_IFACE=$(n1 "ip -o addr show | grep '192.168.56.101' | awk '{print \$2}'")
if [ -n "${ACTIVE_IFACE}" ]; then
  ok "インターフェース ${ACTIVE_IFACE} がアクティブ"
else
  fail "192.168.56.101 を持つアクティブなインターフェースがない"
fi

# 静的設定の確認 (nmcli で ipv4.method=manual)
STATIC_CHECK=$(n1 "nmcli -t -f ipv4.method con show 2>/dev/null | grep -c 'manual'" 2>/dev/null)
if [ "${STATIC_CHECK:-0}" -ge 1 ]; then
  ok "静的IP (manual) 設定が存在する"
else
  fail "静的IP設定が見つからない"
fi

# 永続設定の確認 (NetworkManager コネクションファイルに autoconnect=yes)
if n1 "nmcli -t -f connection.autoconnect con show 2>/dev/null | grep -q 'yes'"; then
  ok "autoconnect が有効 (再起動後も維持)"
else
  skip "autoconnect 確認スキップ"
fi

# ── ユーザー・グループ ────────────────────────────────────────────
echo ""
echo "【ユーザー・グループ管理】"

if n1 "getent group developer" | grep -q ":60000:"; then
  ok "グループ developer (GID 60000) が存在"
else
  fail "グループ developer (GID 60000) が存在しない"
fi

for user in user01 user02; do
  if n1 "id ${user}" | grep -q "developer"; then
    ok "${user} が developer グループのメンバー"
  else
    fail "${user} が developer グループのメンバーでない"
  fi

  SHELL=$(n1 "getent passwd ${user} | cut -d: -f7")
  if echo "${SHELL}" | grep -q "bash"; then
    ok "${user} のシェルが bash"
  else
    fail "${user} のシェルが bash でない (${SHELL:-?})"
  fi
done

SHELL03=$(n1 "getent passwd user03 2>/dev/null | cut -d: -f7")
if echo "${SHELL03}" | grep -qi "nologin"; then
  ok "user03 のシェルが nologin"
else
  fail "user03 のシェルが nologin でない (${SHELL03:-?})"
fi

UID04=$(n1 "id -u user04 2>/dev/null")
if [ "${UID04:-0}" = "3000" ]; then
  ok "user04 の UID が 3000"
else
  fail "user04 の UID が 3000 でない (${UID04:-?})"
fi

# パスワード確認
if n1 "echo 'password' | su -c 'echo __OK__' - user01 2>/dev/null" | grep -q "__OK__"; then
  ok "user01 のパスワードが 'password'"
else
  skip "user01 パスワード確認スキップ"
fi

# ── ファイル権限 ──────────────────────────────────────────────────
echo ""
echo "【ファイル権限】"

DIR_GROUP=$(n1 "stat -c '%G' /data/developer 2>/dev/null")
if [ "${DIR_GROUP}" = "developer" ]; then
  ok "/data/developer のグループ所有者が developer"
else
  fail "/data/developer のグループ所有者が developer でない (${DIR_GROUP:-?})"
fi

DIR_PERM=$(n1 "stat -c '%a' /data/developer 2>/dev/null")
if echo "${DIR_PERM}" | grep -qE "^2[67][07]0$"; then
  ok "/data/developer にsetgidビット設定 (${DIR_PERM})"
else
  fail "/data/developer にsetgidビット未設定 (octal: ${DIR_PERM:-?}, expect 2770)"
fi

# other パーミッションが 0 であることを確認
OTHER_PERM=$(n1 "stat -c '%a' /data/developer 2>/dev/null | cut -c4")
if [ "${OTHER_PERM:-x}" = "0" ]; then
  ok "/data/developer は other ユーザーアクセス不可"
else
  fail "/data/developer は other ユーザーがアクセスできる (${DIR_PERM:-?})"
fi

SHARED_PERM=$(n1 "stat -c '%a' /data/shared 2>/dev/null")
if echo "${SHARED_PERM}" | grep -qE "^1[0-9]{3}$"; then
  ok "/data/shared に sticky bit 設定 (${SHARED_PERM})"
else
  fail "/data/shared に sticky bit 未設定 (octal: ${SHARED_PERM:-?}, expect 1777)"
fi

# ACL: user04 が /data/developer に r 権限
ACL=$(n1 "getfacl /data/developer 2>/dev/null | grep 'user:user04'")
if echo "${ACL}" | grep -q "r"; then
  ok "ACL: user04 が /data/developer に読み取り権限"
else
  fail "ACL: user04 の /data/developer 読み取り権限が設定されていない"
fi

# ── autofs ────────────────────────────────────────────────────────
echo ""
echo "【autofs】"

if n1 "systemctl is-active autofs 2>/dev/null" | grep -q "^active$"; then
  ok "autofs サービスが稼働中"
else
  fail "autofs サービスが稼働していない"
fi

if n1 "systemctl is-enabled autofs 2>/dev/null" | grep -q "enabled"; then
  ok "autofs が enable 設定 (永続)"
else
  fail "autofs が enable されていない"
fi

# マウント確認 (ls でアクセスして autofs をトリガー)
if n1 "ls /mnt/remote/data 2>/dev/null && echo __MOUNTED__" | grep -q "__MOUNTED__"; then
  ok "/mnt/remote/data にアクセス成功 (autofs マウント動作)"
else
  fail "/mnt/remote/data へのアクセス失敗 (autofs 未動作)"
fi

MASTER=$(n1 "cat /etc/auto.master.d/*.autofs 2>/dev/null || grep -v '^#' /etc/auto.master 2>/dev/null")
if echo "${MASTER}" | grep -q "/mnt/remote"; then
  ok "マスターマップに /mnt/remote エントリが存在"
else
  fail "マスターマップに /mnt/remote エントリが見つからない"
fi

# ── 圧縮・アーカイブ ──────────────────────────────────────────────
echo ""
echo "【圧縮・アーカイブ】"

if n1 "test -f /tmp/log_backup.tar.gz && echo __OK__" | grep -q "__OK__"; then
  ok "/tmp/log_backup.tar.gz が存在"
else
  fail "/tmp/log_backup.tar.gz が存在しない"
fi

if n1 "file /tmp/log_backup.tar.gz 2>/dev/null" | grep -qi "gzip"; then
  ok "/tmp/log_backup.tar.gz が gzip 形式"
else
  fail "/tmp/log_backup.tar.gz が gzip 形式でない"
fi

if n1 "tar tzf /tmp/log_backup.tar.gz 2>/dev/null | grep -q 'log'" ; then
  ok "/tmp/log_backup.tar.gz に /var/log の内容が含まれる"
else
  fail "/tmp/log_backup.tar.gz に /var/log の内容がない"
fi

if n1 "test -f /tmp/etc_backup.tar.bz2 && echo __OK__" | grep -q "__OK__"; then
  ok "/tmp/etc_backup.tar.bz2 が存在"
else
  fail "/tmp/etc_backup.tar.bz2 が存在しない"
fi

if n1 "file /tmp/etc_backup.tar.bz2 2>/dev/null" | grep -qi "bzip2"; then
  ok "/tmp/etc_backup.tar.bz2 が bzip2 形式"
else
  fail "/tmp/etc_backup.tar.bz2 が bzip2 形式でない"
fi

if n1 "tar tjf /tmp/etc_backup.tar.bz2 2>/dev/null | grep -q 'etc'" ; then
  ok "/tmp/etc_backup.tar.bz2 に /etc の内容が含まれる"
else
  fail "/tmp/etc_backup.tar.bz2 に /etc の内容がない"
fi

# ── 結果 ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
TOTAL=$((PASS + FAIL))
PCT=0; [ "${TOTAL}" -gt 0 ] && PCT=$((PASS * 100 / TOTAL))
echo -e " スコア: ${GREEN}${PASS}${NC} / ${TOTAL}  (${PCT}%)  SKIP: ${SKIP}"
echo "============================================================"
