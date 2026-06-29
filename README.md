# [RHCSA] M1 Mac 向け RHCSA 試験シミュレーター — Vagrant + VMware + Ansible

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Apple%20Silicon%20(M1%2FM2%2FM3)-lightgrey)
![Vagrant](https://img.shields.io/badge/vagrant-2.3%2B-1563FF?logo=vagrant)
![Ansible](https://img.shields.io/badge/ansible-2.14%2B-EE0000?logo=ansible)

---

## 背景

RHCSA（Red Hat Certified System Administrator）の試験対策をしていて、毎回 VM を手作業でセットアップするのが面倒だと感じていました。

特に以下の点が課題でした。

- **node1**：ネットワーク未設定の状態から始める課題（`nmcli` 設定）
- **node2**：root パスワードが不明な状態から始める課題（`rd.break` 回復）
- 毎回手作業で VM を初期化するのは時間がかかる
- 採点を客観的に行えない

そこで `vagrant up` 一発で試験環境を再現できるシミュレーターを作りました。

---

## RHCSA とは

RHCSA は Red Hat が主催する Linux システム管理者向けの認定資格です。試験は実機操作形式（筆記なし）で、制限時間内に与えられた課題をコマンドラインで解決します。

主な出題範囲：

- ユーザー・グループ管理（`useradd` / `groupadd` / `usermod`）
- ファイル権限・ACL（`chmod` / `chown` / `setfacl`）
- ネットワーク設定（`nmcli`）
- ファイルシステム・LVM（`pvcreate` / `vgcreate` / `lvcreate` / `xfs_growfs`）
- SWAP 領域の追加（`fdisk` / `mkswap` / `swapon`）
- 自動マウント（`autofs`）
- コンテナ（`podman` rootless + systemd ユーザーサービス）

---

## シミュレーターの構成

### 要件

| ツール | バージョン |
|--------|-----------|
| macOS (Apple Silicon M1/M2/M3) | — |
| VMware Fusion | 13+ |
| Vagrant | 2.3+ |
| vagrant-vmware-desktop プラグイン | — |
| Ansible | 2.14+ |

```bash
vagrant plugin install vagrant-vmware-desktop
```

### ネットワーク設計

| NIC | 用途 | node1 | node2 |
|-----|------|-------|-------|
| `ens33` (NAT) | Vagrant 管理用（常時有効） | 自動 | 自動 |
| `ens36` (host-only) | 試験用ネットワーク | **未設定**（exam task） | `192.168.56.102` |

### 初期状態（exam state）

| | node1 | node2 |
|-|-------|-------|
| **試験課題** | ネットワーク・ユーザー/グループ・権限・autofs・圧縮 | root パスワード回復・LVM・SWAP・コンテナ |
| **root パスワード** | `redhat`（既知） | ランダム（**不明**） |
| **tester パスワード** | `testpass` | `testpass` |
| **第 2 NIC** | 未設定（exam task） | `192.168.56.102`（設定済み） |
| **NFS** | autofs クライアント候補 | `/exports/data` を公開 |
| **追加ディスク** | なし | `/dev/sdb` 5GB（LVM 用）、`/dev/sdc` 3GB（SWAP 用） |

---

## ファイル構造

```
.
├── Vagrantfile                  # VM 定義（node1/node2、extra disks、trigger）
├── Makefile                     # ショートカットコマンド
├── LICENSE                      # MIT License
├── PROBLEM.md                   # 試験問題集（日本語）
├── scripts/
│   ├── node1_bootstrap.sh       # node1 初期化（ネットワーク未設定状態を作成）
│   ├── node2_bootstrap.sh       # node2 初期化（root パスランダム化、NFS 設定）
│   └── gen_inventory.sh         # vagrant ssh-config → ansible/inventory.ini
├── shells/
│   └── validate.sh              # 全体バリデーション（静的チェック + 採点）
├── score/
│   ├── score_node1.sh           # node1 採点スクリプト
│   └── score_node2.sh           # node2 採点スクリプト
├── answers/
│   ├── node1/                   # node1 解答スクリプト（01〜05）
│   └── node2/                   # node2 解答スクリプト（01〜05）
└── ansible/
    ├── ansible.cfg
    ├── inventory.ini            # vagrant up 後に自動生成
    ├── group_vars/all.yaml
    └── playbooks/
        ├── bootstrap.yaml       # 追加設定 playbook
        ├── ssh_copy.yaml        # SSH キー配布 playbook
        └── lockdown.yaml        # SSH キー削除 → パスワード認証のみ
```

---

## クイックスタート

### 1. VM 起動

```bash
make up
```

`vagrant up --parallel` を実行し、node1 / node2 を同時起動します。起動後、`ansible/inventory.ini` が自動生成されます。

### 2. フルセットアップ（推奨）

```bash
make setup
```

以下を一括実行します。

1. `make up` — VM 起動
2. `make ssh-copy` — Ansible 用 SSH キーを一時配布（パスワード入力: `testpass`）
3. `make bootstrap` — NFS・パッケージなど追加設定
4. `make lockdown` — SSH キーを削除してパスワード認証のみに戻す（RHCSA 試験状態）

### 3. VM に接続

```bash
make ssh1   # node1 に接続（tester / testpass）
make ssh2   # node2 に接続（tester / testpass）
```

### 4. 採点

```bash
make score1                         # node1 採点
make score2                         # node2 採点（root パスワードを対話入力）
bash score/score_node2.sh newroot   # root パスを引数で指定
```

### 5. 解答確認（答え合わせ）

```bash
# 解答スクリプトを適用してから採点（ゼロから検証）
bash shells/validate.sh --apply-answers
```

### 6. 環境削除

```bash
make destroy
```

---

## 試験課題（PROBLEM.md より抜粋）

### node1

| # | 課題 | キーワード |
|---|------|-----------|
| 1 | ens36 に静的 IP `192.168.56.101/24` を設定 | `nmcli con add` |
| 2 | グループ `developer`（GID 60000）、ユーザー user01〜04 を作成 | `groupadd` / `useradd` |
| 3 | `/data/developer` に setgid (2770)、`/data/shared` に sticky (1777)、user04 に ACL | `chmod` / `setfacl` |
| 4 | node2 の NFS エクスポートを `/mnt/remote/data` に autofs でマウント | `autofs` / `auto.master` |
| 5 | `/var/log` を `.tar.gz`、`/etc` を `.tar.bz2` でアーカイブ | `tar czf` / `tar cjf` |

### node2

| # | 課題 | キーワード |
|---|------|-----------|
| 1 | rd.break で root パスワードを `newroot` に変更 | `rd.break` / `chroot` |
| 2 | DNF リポジトリを登録して `telnet` をインストール | `dnf config-manager` |
| 3 | `/dev/sdb` に VG `vg_data`（PE=16MB）、LV `lv_web` 2GB→3GB、XFS で `/web` にマウント | `pvcreate` / `lvcreate` / `xfs_growfs` |
| 4 | `/dev/sdc` に 1GB SWAP パーティションを追加 | `fdisk` / `mkswap` / `swapon` |
| 5 | `tester` ユーザーで nginx コンテナ `web`（8080:80）を起動、systemd ユーザーサービスで自動起動 | `podman` / `loginctl linger` |

---

## 採点の仕組み

採点スクリプトは VM 上で各設定を検証し、PASS / FAIL / SKIP を出力します。

```
============================================================
 RHCSA Simulator — node1 採点
============================================================

【ネットワーク設定】
  [PASS] ens36 に静的 IP が設定されている (192.168.56.101/24)
  [PASS] ipv4.method = manual

【ユーザー・グループ】
  [PASS] グループ developer (GID=60000) が存在
  [PASS] user01 が developer グループに所属
  ...

============================================================
 スコア: 12 / 14  (85%)  SKIP: 1
============================================================
```

採点は VM 起動中にいつでも実行できます。

---

## Makefile コマンド一覧

| コマンド | 説明 |
|---------|------|
| `make up` | VM 起動（vagrant up --parallel） |
| `make down` | VM 停止 |
| `make destroy` | VM 削除 |
| `make setup` | 推奨: up→ssh-copy→bootstrap→lockdown を一括実行 |
| `make ssh1` | node1 に SSH |
| `make ssh2` | node2 に SSH |
| `make score1` | node1 採点 |
| `make score2` | node2 採点 |
| `make validate` | 全体バリデーション（静的チェック + 採点） |
| `make inventory` | ansible/inventory.ini を再生成 |
| `make create-disks` | node2 用 extra VMDK を手動作成 |
| `make clean` | VM 削除 + disks 削除 |
| `make git-push` | ステージ・コミット・push を一括実行 |

---

## トラブルシューティング

**VM が起動しない（VMDK エラー）**

```bash
make create-disks   # extra disks を手動作成してから再度 vagrant up
```

**Ansible が接続できない**

```bash
make inventory      # inventory.ini を再生成
vagrant ssh-config  # SSH 設定を確認
```

**node1 の第 2 NIC が見つからない**

```bash
vagrant ssh node1
ip link show        # インターフェース名を確認
nmcli dev status
```

**node2 で podman イメージが取得できない**

```bash
# NAT 経由でインターネットアクセスが必要
vagrant ssh node2
curl -I https://registry-1.docker.io
```

---

## ライセンス

[MIT License](./LICENSE) © 2026 kanei0415
