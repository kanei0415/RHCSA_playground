#!/bin/bash
# RHCSA Simulator — Full Validation Script
# フロー: static check → vagrant status → answer shells → score shells
# Usage: bash shells/validate.sh [--apply-answers] [--score-only]

set -uo pipefail
cd "$(dirname "$0")/.."   # Run from project root

APPLY_ANSWERS=false
SCORE_ONLY=false
for arg in "$@"; do
  case "${arg}" in
    --apply-answers) APPLY_ANSWERS=true ;;
    --score-only)    SCORE_ONLY=true    ;;
  esac
done

# ── カラー定義 ────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; BOLD='\033[1m'; NC='\033[0m'

S_PASS=0; S_FAIL=0; S_WARN=0

ok()     { echo -e "  ${GREEN}[PASS]${NC} $*"; ((S_PASS++)); }
fail()   { echo -e "  ${RED}[FAIL]${NC} $*"; ((S_FAIL++)); }
warn()   { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((S_WARN++)); }
info()   { echo -e "  ${BLUE}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}══════ $* ══════${NC}"; }

# ── ヘルパー ──────────────────────────────────────────────────────
run_on() {
  local node="$1" script="$2" as_root="${3:-sudo}"
  local cmd="sudo bash -s"
  [ "${as_root}" = "user" ] && cmd="bash -s"
  vagrant ssh "${node}" -- ${cmd} < "${script}" 2>&1
}

vm_running() {
  vagrant status "$1" 2>/dev/null | grep -q "running"
}

# ══════════════════════════════════════════════════════════════════
header "Phase 1: 静的構文チェック"
# ══════════════════════════════════════════════════════════════════

if ${SCORE_ONLY}; then
  info "Skipping static checks (--score-only)"
else

  # Vagrantfile
  if ruby -c Vagrantfile &>/dev/null 2>&1; then
    ok "Vagrantfile ruby syntax"
  else
    fail "Vagrantfile syntax error: $(ruby -c Vagrantfile 2>&1)"
  fi

  # Bash scripts — all .sh files
  FAILED_SH=()
  while IFS= read -r f; do
    if bash -n "${f}" 2>/dev/null; then
      ok "bash -n: ${f}"
    else
      fail "bash syntax error: ${f}"
      FAILED_SH+=("${f}")
    fi
  done < <(find scripts shells score answers -name "*.sh" 2>/dev/null | sort)

  # Ansible playbooks (if ansible-playbook is available)
  if command -v ansible-playbook &>/dev/null; then
    while IFS= read -r f; do
      if ansible-playbook --syntax-check -i ansible/inventory.ini "${f}" &>/dev/null 2>&1; then
        ok "ansible syntax: ${f}"
      else
        fail "ansible syntax error: ${f}"
      fi
    done < <(find ansible/playbooks -name "*.yaml" 2>/dev/null | sort)
  else
    warn "ansible-playbook not found — skipping playbook syntax check"
  fi

  # Makefile targets exist
  for target in up down ssh1 ssh2 setup lockdown score1 score2 validate; do
    if grep -q "^${target}:" Makefile 2>/dev/null; then
      ok "Makefile target: ${target}"
    else
      fail "Makefile target missing: ${target}"
    fi
  done

  # Required files exist
  REQUIRED=(
    Vagrantfile Makefile PROBLEM.md CLAUDE.md
    scripts/node1_bootstrap.sh scripts/node2_bootstrap.sh scripts/gen_inventory.sh
    ansible/ansible.cfg ansible/inventory.ini
    ansible/playbooks/bootstrap.yaml ansible/playbooks/ssh_copy.yaml ansible/playbooks/lockdown.yaml
    answers/node1/01_network.sh answers/node1/02_users_groups.sh
    answers/node1/03_permissions.sh answers/node1/04_autofs.sh answers/node1/05_compression.sh
    answers/node2/01_root_password.sh answers/node2/02_repo.sh
    answers/node2/03_lvm.sh answers/node2/04_swap.sh answers/node2/05_container.sh
    score/score_node1.sh score/score_node2.sh
    shells/validate.sh
  )
  for f in "${REQUIRED[@]}"; do
    if [ -e "${f}" ]; then
      ok "exists: ${f}"
    else
      fail "missing: ${f}"
    fi
  done

fi  # /SCORE_ONLY

# ══════════════════════════════════════════════════════════════════
header "Phase 2: Vagrant VM 状態確認"
# ══════════════════════════════════════════════════════════════════

N1_UP=false; N2_UP=false

if vm_running node1; then
  ok "node1 is running"
  N1_UP=true
else
  warn "node1 is NOT running"
  info "Run: make up  (or: vagrant up node1)"
fi

if vm_running node2; then
  ok "node2 is running"
  N2_UP=true
else
  warn "node2 is NOT running"
  info "Run: make up  (or: vagrant up node2)"
fi

if ! ${N1_UP} && ! ${N2_UP}; then
  echo ""
  echo -e "${YELLOW}VMs are not running — skipping runtime checks${NC}"
  echo -e "${YELLOW}Run 'make up' then re-run this script${NC}"
  echo ""
  header "Final Report (static only)"
  echo -e "  PASS: ${GREEN}${S_PASS}${NC}  FAIL: ${RED}${S_FAIL}${NC}  WARN: ${YELLOW}${S_WARN}${NC}"
  exit $([ "${S_FAIL}" -eq 0 ] && echo 0 || echo 1)
fi

# ══════════════════════════════════════════════════════════════════
header "Phase 3: 基本接続確認"
# ══════════════════════════════════════════════════════════════════

if ${N1_UP}; then
  if vagrant ssh node1 -- echo "__PING__" 2>/dev/null | grep -q "__PING__"; then
    ok "SSH to node1: OK"
  else
    fail "SSH to node1: FAILED"
    N1_UP=false
  fi
fi

if ${N2_UP}; then
  if vagrant ssh node2 -- echo "__PING__" 2>/dev/null | grep -q "__PING__"; then
    ok "SSH to node2: OK"
  else
    fail "SSH to node2: FAILED"
    N2_UP=false
  fi
fi

# node2 NFS server check (needed for node1 autofs)
if ${N2_UP}; then
  if vagrant ssh node2 -- sudo systemctl is-active nfs-server 2>/dev/null | grep -q "^active$"; then
    ok "node2: NFS server is active (needed for node1 autofs)"
  else
    warn "node2: NFS server not active — node1 autofs test may fail"
  fi
fi

# ══════════════════════════════════════════════════════════════════
header "Phase 4: Answer Scripts 適用"
# ══════════════════════════════════════════════════════════════════

if ! ${APPLY_ANSWERS}; then
  info "Skipping answer application (run with --apply-answers to apply)"
  info "  bash shells/validate.sh --apply-answers"
else

  if ${N1_UP}; then
    echo ""
    echo -e "  ${BOLD}--- node1 answers ---${NC}"

    # 01: Network (must be first — autofs needs it)
    info "Applying: answers/node1/01_network.sh"
    if run_on node1 answers/node1/01_network.sh sudo >/dev/null 2>&1; then
      ok "answers/node1/01_network.sh applied"
    else
      fail "answers/node1/01_network.sh failed"
    fi

    for N in 02 03 04 05; do
      F=$(ls answers/node1/${N}_*.sh 2>/dev/null | head -1)
      [ -z "${F}" ] && { warn "answers/node1/${N}_*.sh not found"; continue; }
      info "Applying: ${F}"
      if run_on node1 "${F}" sudo >/dev/null 2>&1; then
        ok "${F} applied"
      else
        fail "${F} failed"
      fi
    done
  fi

  if ${N2_UP}; then
    echo ""
    echo -e "  ${BOLD}--- node2 answers ---${NC}"

    for N in 01 02 03 04; do
      F=$(ls answers/node2/${N}_*.sh 2>/dev/null | head -1)
      [ -z "${F}" ] && { warn "answers/node2/${N}_*.sh not found"; continue; }
      info "Applying: ${F}"
      if run_on node2 "${F}" sudo >/dev/null 2>&1; then
        ok "${F} applied"
      else
        fail "${F} failed"
      fi
    done

    # 05: Container runs as tester (passed as root, script delegates internally)
    F="answers/node2/05_container.sh"
    info "Applying: ${F} (delegates to tester internally)"
    if run_on node2 "${F}" sudo >/dev/null 2>&1; then
      ok "${F} applied"
    else
      fail "${F} failed"
    fi
  fi

fi  # /APPLY_ANSWERS

# ══════════════════════════════════════════════════════════════════
header "Phase 5: 採点実行"
# ══════════════════════════════════════════════════════════════════

if ${N1_UP}; then
  echo ""
  echo -e "${BOLD}┌── node1 採点 ──────────────────────────────────┐${NC}"
  bash score/score_node1.sh 2>/dev/null
  echo -e "${BOLD}└────────────────────────────────────────────────┘${NC}"
fi

if ${N2_UP}; then
  echo ""
  echo -e "${BOLD}┌── node2 採点 ──────────────────────────────────┐${NC}"
  bash score/score_node2.sh newroot 2>/dev/null
  echo -e "${BOLD}└────────────────────────────────────────────────┘${NC}"
fi

# ══════════════════════════════════════════════════════════════════
header "Final Report"
# ══════════════════════════════════════════════════════════════════
echo -e "  Validation:  PASS=${GREEN}${S_PASS}${NC}  FAIL=${RED}${S_FAIL}${NC}  WARN=${YELLOW}${S_WARN}${NC}"
echo ""
echo "  Usage:"
echo "    bash shells/validate.sh                  # static + status + score"
echo "    bash shells/validate.sh --apply-answers  # + apply all answers before scoring"
echo "    bash shells/validate.sh --score-only     # scoring only (skip static)"
echo ""

[ "${S_FAIL}" -eq 0 ] && exit 0 || exit 1
