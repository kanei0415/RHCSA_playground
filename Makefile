.PHONY: up down destroy ssh1 ssh2 provision status score1 score2 inventory create-disks clean lockdown setup help git-push

# ── VM ライフサイクル ───────────────────────────────────────────────────────
up:
	vagrant up --parallel

down:
	vagrant halt

destroy:
	vagrant destroy -f

provision:
	vagrant provision

status:
	vagrant status

# ── SSH アクセス ─────────────────────────────────────────────────────────────
ssh1:
	vagrant ssh node1

ssh2:
	vagrant ssh node2

# ── Ansible ─────────────────────────────────────────────────────────────────
inventory:
	bash scripts/gen_inventory.sh

bootstrap:
	cd ansible && ansible-playbook playbooks/bootstrap.yaml

ssh-copy:
	cd ansible && ansible-playbook playbooks/ssh_copy.yaml --ask-pass

# SSH キー削除 — Ansible 作業完了後にパスワード認証のみに戻す (RHCSA exam state)
lockdown:
	cd ansible && ansible-playbook playbooks/lockdown.yaml --ask-pass

# フルセットアップ: up → キー配布 → bootstrap → キー削除 (推奨フロー)
setup: up
	@echo ">>> [1/3] SSH キーを配布中 (パスワード: testpass)..."
	cd ansible && ansible-playbook playbooks/ssh_copy.yaml --ask-pass
	@echo ">>> [2/3] Bootstrap playbook 実行中..."
	cd ansible && ansible-playbook playbooks/bootstrap.yaml
	@echo ">>> [3/3] SSH キーを削除してパスワード認証のみに戻す..."
	cd ansible && ansible-playbook playbooks/lockdown.yaml
	@echo ""
	@echo "==== セットアップ完了 ===="
	@echo "  node1: vagrant ssh node1  (tester / testpass)"
	@echo "  node2: vagrant ssh node2  (tester / testpass)"
	@echo "  採点:  make score1 / make score2"

# ── 採点 ────────────────────────────────────────────────────────────────────
score1:
	bash score/score_node1.sh

score2:
	@read -p "node2 の新しい root パスワード [newroot]: " PW; \
	bash score/score_node2.sh $${PW:-newroot}

validate:
	bash shells/validate.sh

# ── Extra disks (手動作成が必要な場合) ──────────────────────────────────────
VMDK_MGR = /Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager
DISKS_DIR = .vagrant/disks

create-disks:
	mkdir -p "$(DISKS_DIR)"
	"$(VMDK_MGR)" -c -t 0 -s 5120MB -a lsilogic "$(DISKS_DIR)/sdb.vmdk"
	"$(VMDK_MGR)" -c -t 0 -s 3072MB -a lsilogic "$(DISKS_DIR)/sdc.vmdk"
	@echo "Disks created in $(DISKS_DIR)/"

# ── Git ─────────────────────────────────────────────────────────────────────
git-push:
	git add -A
	git commit -m "Update simulator"
	git push origin main

# ── クリーンアップ ────────────────────────────────────────────────────────────
clean: destroy
	rm -rf .vagrant/disks

# ── ヘルプ ───────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  RHCSA Simulator Bootstrapper — M1 Mac"
	@echo ""
	@echo "  make up           VM 起動 (vagrant up --parallel)"
	@echo "  make down         VM 停止"
	@echo "  make destroy      VM 削除"
	@echo "  make ssh1         node1 に SSH"
	@echo "  make ssh2         node2 に SSH"
	@echo "  make status       VM 状態確認"
	@echo "  make setup        推奨: up→ssh-copy→bootstrap→lockdown を一括実行"
	@echo "  make inventory    ansible/inventory.ini を再生成"
	@echo "  make ssh-copy     SSH 公開キーを配布 (Ansible 作業用・一時的)"
	@echo "  make bootstrap    Ansible bootstrap playbook 実行"
	@echo "  make lockdown     SSH キー削除 → パスワード認証のみ (RHCSA exam state)"
	@echo "  make score1       node1 採点"
	@echo "  make score2       node2 採点"
	@echo "  make create-disks node2 用 extra VMDK を手動作成"
	@echo "  make clean        VM 削除 + disks 削除"
	@echo ""
	@echo "  推奨フロー: make setup (一括) または"
	@echo "    1. make up"
	@echo "    2. make ssh-copy   # 初回: --ask-pass でパスワード入力"
	@echo "    3. make bootstrap"
	@echo "    4. make lockdown   # SSH キー削除 → RHCSA 試験状態"
	@echo ""
