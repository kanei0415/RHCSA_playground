#!/bin/bash
# [node2] 問題5: Podman rootless コンテナ (idempotent)
# tester ユーザーで nginx コンテナを起動し systemd ユーザーサービスで自動起動
# このスクリプトは root で呼び出してもよい (内部で tester に委譲)
set -euo pipefail

TESTER="tester"
TESTER_UID=$(id -u "${TESTER}" 2>/dev/null)
TESTER_HOME=$(getent passwd "${TESTER}" | cut -d: -f6)
XDG_RT="/run/user/${TESTER_UID}"
SYSTEMD_DIR="${TESTER_HOME}/.config/systemd/user"
IMAGE="docker.io/library/nginx:latest"
CONTAINER="web"
HOST_PORT="8080"

# tester として podman コマンドを実行するラッパー
p() { sudo -u "${TESTER}" XDG_RUNTIME_DIR="${XDG_RT}" "$@"; }

# ── linger 有効化 (root で実行) ───────────────────────────────────
echo ">>> Enabling linger for ${TESTER}"
loginctl enable-linger "${TESTER}"

# ── user systemd の起動 (XDG_RUNTIME_DIR が存在しない場合) ───────
if [ ! -d "${XDG_RT}" ]; then
  echo ">>> Starting user systemd session for ${TESTER}"
  mkdir -p "${XDG_RT}"
  chown "${TESTER}:${TESTER}" "${XDG_RT}"
fi

# ── イメージ取得 ──────────────────────────────────────────────────
echo ">>> Pulling image: ${IMAGE}"
p podman pull "${IMAGE}" 2>/dev/null || true

# ── 既存コンテナ削除 (idempotent) ────────────────────────────────
echo ">>> Stopping/removing existing container '${CONTAINER}' (if any)"
p podman stop "${CONTAINER}" 2>/dev/null || true
p podman rm   "${CONTAINER}" 2>/dev/null || true

# ── コンテナ起動 ──────────────────────────────────────────────────
echo ">>> Starting container: ${CONTAINER}"
p podman run -d \
  --name "${CONTAINER}" \
  -p "${HOST_PORT}:80" \
  --restart always \
  "${IMAGE}"

# ── systemd ユーザーサービス生成 ─────────────────────────────────
echo ">>> Generating systemd user service"
mkdir -p "${SYSTEMD_DIR}"
chown -R "${TESTER}:${TESTER}" "${TESTER_HOME}/.config"

# 生成 (--new: コンテナが存在しなくても再生成・起動できる)
p podman generate systemd \
  --name "${CONTAINER}" \
  --new \
  --restart-policy always \
  --files \
  --container-prefix "" \
  2>/dev/null || \
p podman generate systemd \
  --name "${CONTAINER}" \
  --new \
  --files \
  2>/dev/null

# 生成されたサービスファイルを systemd ディレクトリへ移動
SVC_FILE=$(find /tmp "${TESTER_HOME}" -maxdepth 2 -name "*${CONTAINER}*.service" 2>/dev/null | head -1)
if [ -z "${SVC_FILE}" ]; then
  # podman 4.x では --files でカレントディレクトリに生成
  cd /tmp
  p podman generate systemd --name "${CONTAINER}" --new --files 2>/dev/null
  SVC_FILE=$(find /tmp -maxdepth 1 -name "*${CONTAINER}*.service" 2>/dev/null | head -1)
fi

if [ -n "${SVC_FILE}" ] && [ "$(dirname "${SVC_FILE}")" != "${SYSTEMD_DIR}" ]; then
  echo ">>> Moving ${SVC_FILE} → ${SYSTEMD_DIR}/"
  mv "${SVC_FILE}" "${SYSTEMD_DIR}/"
  chown "${TESTER}:${TESTER}" "${SYSTEMD_DIR}/"*".service"
fi

# ── サービスを有効化・起動 ────────────────────────────────────────
echo ">>> Enabling systemd user service"
p systemctl --user daemon-reload

# サービス名を検索 (container-web.service or web.service)
SVC_NAME=$(p systemctl --user list-unit-files 2>/dev/null | \
           grep -E "(container-)?${CONTAINER}\.service" | awk '{print $1}' | head -1)
SVC_NAME="${SVC_NAME:-container-${CONTAINER}.service}"

p systemctl --user enable "${SVC_NAME}" 2>/dev/null || true
p systemctl --user start  "${SVC_NAME}" 2>/dev/null || true

echo ">>> Verify:"
p podman ps --filter name="${CONTAINER}"
p systemctl --user is-enabled "${SVC_NAME}" 2>/dev/null || true
loginctl show-user "${TESTER}" | grep Linger
