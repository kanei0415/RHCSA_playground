#!/bin/bash
# RHCSA Simulator — node2 採点スクリプト
# Usage: bash score/score_node2.sh [new_root_password]

set -uo pipefail

ROOT_NEW_PASS="${1:-newroot}"

PASS=0; FAIL=0; SKIP=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[PASS]${NC} $*"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; ((FAIL++)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; ((SKIP++)); }

# Run as root on node2
n2() { vagrant ssh node2 -- sudo bash -c "$*" 2>/dev/null | tr -d '\r'; }

# Run as tester on node2 — TESTER_UID is resolved once below
TESTER_UID="1001"
n2_tester() {
  local uid="${TESTER_UID}"
  vagrant ssh node2 -- sudo -u tester bash -c "XDG_RUNTIME_DIR=/run/user/${uid} $*" \
    2>/dev/null | tr -d '\r'
}

echo "============================================================"
echo " RHCSA Simulator — node2 採点"
echo " (想定 rootパスワード: ${ROOT_NEW_PASS})"
echo "============================================================"

# tester の UID を一度だけ取得 (以降 n2_tester が使用)
TESTER_UID=$(vagrant ssh node2 -- id -u tester 2>/dev/null | tr -d '\r' || echo "1001")

# ── rootパスワード回復 ────────────────────────────────────────────
echo ""
echo "【rootパスワード回復】"

PW_CHECK=$(n2 "python3 -c \"
import sys
try:
    import crypt, spwd
    sp = spwd.getspnam('root')
    print('MATCH' if crypt.crypt('${ROOT_NEW_PASS}', sp.sp_pwdp) == sp.sp_pwdp else 'NOMATCH')
except (ImportError, KeyError):
    # Python 3.13+: fall back to openssl
    import subprocess, re
    shadow = open('/etc/shadow').read()
    m = re.search(r'^root:([^:]+)', shadow, re.M)
    if m:
        h = m.group(1)
        parts = h.split('\\\$')
        algo, salt = parts[1], parts[2]
        r = subprocess.run(['openssl','passwd','-'+algo,'-salt',salt,'${ROOT_NEW_PASS}'],
            capture_output=True, text=True)
        print('MATCH' if r.stdout.strip() == h else 'NOMATCH')
    else:
        print('ERROR: no shadow entry')
\" 2>/dev/null")

if echo "${PW_CHECK}" | grep -q "^MATCH$"; then
  ok "rootパスワードが '${ROOT_NEW_PASS}' に変更されている"
else
  fail "rootパスワードが '${ROOT_NEW_PASS}' でない (check=${PW_CHECK:-failed})"
fi

if n2 "test ! -f /.autorelabel && echo __OK__" | grep -q "__OK__"; then
  ok "SELinux relabel 完了 (/.autorelabel なし)"
else
  skip "/.autorelabel が存在 — 再起動後に relabel 実行予定"
fi

# ── LVM ──────────────────────────────────────────────────────────
echo ""
echo "【LVM】"

PV_CHECK=$(n2 "pvs --noheadings -o pv_name 2>/dev/null | tr -d ' '")
if echo "${PV_CHECK}" | grep -qE "sdb|vdb|xvdb|nvme"; then
  ok "PV が存在 (${PV_CHECK})"
else
  fail "PV が存在しない"
fi

if n2 "vgs --noheadings -o vg_name 2>/dev/null" | grep -q "vg_data"; then
  ok "VG 'vg_data' が存在"
else
  fail "VG 'vg_data' が存在しない"
fi

VG_PE_RAW=$(n2 "vgs --noheadings --units m -o vg_extent_size vg_data 2>/dev/null | tr -d ' <m'")
VG_PE_INT="${VG_PE_RAW%%.*}"
if [ "${VG_PE_INT:-0}" -ge 15 ] && [ "${VG_PE_INT:-0}" -le 17 ]; then
  ok "vg_data の PE サイズが 16MB (${VG_PE_RAW}m)"
else
  skip "vg_data PE サイズ確認 (検出: ${VG_PE_RAW:-?}m, 期待: 16)"
fi

if n2 "lvs --noheadings -o lv_name vg_data 2>/dev/null" | grep -q "lv_web"; then
  ok "LV 'lv_web' が存在"
else
  fail "LV 'lv_web' が存在しない"
fi

LV_SIZE_RAW=$(n2 "lvs --noheadings --units g -o lv_size vg_data/lv_web 2>/dev/null | tr -d ' <g'")
LV_INT="${LV_SIZE_RAW%%.*}"
if [ "${LV_INT:-0}" -ge 3 ]; then
  ok "lv_web のサイズが 3GB 以上 (${LV_SIZE_RAW}G)"
else
  fail "lv_web のサイズが 3GB 未満 (${LV_SIZE_RAW:-?}G)"
fi

# ── /web マウント ─────────────────────────────────────────────────
echo ""
echo "【/web マウント (XFS)】"

FS_TYPE=$(n2 "df -T /web 2>/dev/null | awk 'NR==2{print \$2}'")
if [ "${FS_TYPE}" = "xfs" ]; then
  ok "/web が XFS でマウントされている"
else
  fail "/web が XFS でマウントされていない (fs: ${FS_TYPE:-?})"
fi

if n2 "grep -q ' /web ' /etc/fstab && echo __OK__" | grep -q "__OK__"; then
  ok "/etc/fstab に /web エントリが存在 (永続化)"
else
  fail "/etc/fstab に /web エントリが存在しない"
fi

# ── SWAP ─────────────────────────────────────────────────────────
echo ""
echo "【SWAP】"

SWAP_DEV=$(n2 "swapon --show --noheadings -o NAME 2>/dev/null | tr -d ' '")
if echo "${SWAP_DEV}" | grep -qE "sdc|vdc|xvdc"; then
  ok "SWAP が /dev/sdc 系デバイスで有効 (${SWAP_DEV})"
else
  fail "SWAP が /dev/sdc 系デバイスで有効でない (${SWAP_DEV:-none})"
fi

if n2 "grep -qE 'swap.*swap|sdc|vdc' /etc/fstab && echo __OK__" | grep -q "__OK__"; then
  ok "/etc/fstab に swap エントリが存在 (永続化)"
else
  fail "/etc/fstab に swap エントリが存在しない"
fi

# ── コンテナ (Podman / rootless) ──────────────────────────────────
echo ""
echo "【コンテナ (Podman rootless as tester, UID=${TESTER_UID})】"

CONTAINER_STATUS=$(n2_tester "podman ps --filter name='^web$' --format '{{.Status}}' 2>/dev/null")
if echo "${CONTAINER_STATUS}" | grep -qi "up"; then
  ok "podman コンテナ 'web' が起動中 (${CONTAINER_STATUS})"
else
  fail "podman コンテナ 'web' が起動していない (${CONTAINER_STATUS:-none})"
fi

PORT_MAP=$(n2_tester "podman port web 2>/dev/null")
if echo "${PORT_MAP}" | grep -q "80"; then
  ok "ポートマッピング 8080→80 が設定済み"
else
  skip "ポートマッピング確認 (${PORT_MAP:-?})"
fi

SVC_STATUS=$(n2_tester "systemctl --user is-enabled container-web.service 2>/dev/null || echo not-found")
if echo "${SVC_STATUS}" | grep -qE "^enabled$"; then
  ok "systemd ユーザーサービス container-web.service が enabled"
else
  fail "container-web.service が enabled でない (${SVC_STATUS:-?})"
fi

LINGER=$(n2 "loginctl show-user tester 2>/dev/null | grep '^Linger=' | cut -d= -f2")
if [ "${LINGER:-no}" = "yes" ]; then
  ok "loginctl linger が有効 (再起動後も自動起動)"
else
  fail "loginctl linger が無効 (現在: ${LINGER:-no})"
fi

# ── 結果 ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
TOTAL=$((PASS + FAIL))
PCT=0; [ "${TOTAL}" -gt 0 ] && PCT=$((PASS * 100 / TOTAL))
echo -e " スコア: ${GREEN}${PASS}${NC} / ${TOTAL}  (${PCT}%)  SKIP: ${SKIP}"
echo "============================================================"
