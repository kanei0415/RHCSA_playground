# RHCSA 模擬試験問題集

## 接続情報

| 項目 | node1 | node2 |
|------|-------|-------|
| SSHコマンド | `vagrant ssh node1` | `vagrant ssh node2` |
| testerパスワード | `testpass` | `testpass` |
| rootパスワード | `redhat` (既知) | **不明** (試験課題) |

---

## node1 問題

> **初期状態**: 第2NIC (`ens36`) が未設定、rootパスワードは `redhat`

### 問題 1 — ネットワーク設定

第2ネットワークインターフェース（`ens36`）を以下の設定で**永続的に**構成せよ。

- IPアドレス: `192.168.56.101/24`
- ゲートウェイ: なし（この問題では不要）
- 再起動後も設定が維持されること

```bash
# ヒント
nmcli con add type ethernet con-name ens36 ifname ens36 \
  ipv4.addresses 192.168.56.101/24 ipv4.method manual autoconnect yes
nmcli con up ens36
```

---

### 問題 2 — ユーザーとグループの管理

以下の要件でユーザーとグループを作成せよ。

**グループ:**
| グループ名 | GID |
|-----------|-----|
| `developer` | `60000` |

**ユーザー:**
| ユーザー名 | 条件 |
|-----------|------|
| `user01` | `developer` グループのメンバー、bashシェル |
| `user02` | `developer` グループのメンバー、bashシェル |
| `user03` | ログイン不可（`/sbin/nologin`） |
| `user04` | UID `3000`、bashシェル |

- 全ユーザーのパスワードを `password` に設定すること

```bash
# ヒント
groupadd -g 60000 developer
useradd -G developer user01
useradd -G developer user02
useradd -s /sbin/nologin user03
useradd -u 3000 user04
echo 'password' | passwd --stdin user01
# ... 他のユーザーも同様
```

---

### 問題 3 — ファイル権限

以下の要件でディレクトリとパーミッションを設定せよ。

**`/data/developer` ディレクトリ:**
- `developer` グループが所有
- `developer` グループのメンバーのみ読み書き実行可能（`rwxrwx---`、他ユーザーはアクセス不可）
- ディレクトリ内に作成したファイルは**自動的に** `developer` グループを継承（**setgid**）

**`/data/shared` ディレクトリ:**
- 全ユーザーが読み書き実行可能（`rwxrwxrwx`）
- 自分が作成したファイルのみ削除可能（**sticky bit**）

**ACL（追加要件）:**
- `/data/developer` に対し、`user04` のみ**読み取り権限**を付与（setfacl）

```bash
# ヒント
mkdir -p /data/developer /data/shared
chown root:developer /data/developer
chmod 2770 /data/developer       # setgid + rwxrwx---
chmod 1777 /data/shared          # sticky bit + rwxrwxrwx
setfacl -m u:user04:r /data/developer
```

---

### 問題 4 — autofs（自動マウント）

`node2`（`192.168.56.102`）が NFS で `/exports/data` を公開している。  
以下の要件で autofs を設定せよ。

- **間接マップ**を使用
- `/mnt/remote` ディレクトリ配下の `data` にアクセスした際、自動マウント
  - マウント先: `/mnt/remote/data` → `192.168.56.102:/exports/data`
- オプション: `rw,sync`
- autofs サービスが再起動後も自動起動すること

```bash
# ヒント
dnf -y install autofs nfs-utils

# マスターマップ作成
vi /etc/auto.master.d/remote.autofs
  /mnt/remote  /etc/auto.remote

# マップファイル作成
vi /etc/auto.remote
  data  -rw,sync  192.168.56.102:/exports/data

systemctl enable --now autofs

# 確認
ls /mnt/remote/data
```

---

### 問題 5 — 圧縮・アーカイブ

以下のアーカイブを作成せよ。

1. `/var/log` ディレクトリ全体を `/tmp/log_backup.tar.gz`（gzip 圧縮）に圧縮
2. `/etc` ディレクトリ全体を `/tmp/etc_backup.tar.bz2`（bzip2 圧縮）に圧縮
3. `/tmp/etc_backup.tar.bz2` の内容一覧を**ファイルを展開せずに**表示

```bash
# ヒント
tar czf /tmp/log_backup.tar.gz /var/log
tar cjf /tmp/etc_backup.tar.bz2 /etc
tar tjf /tmp/etc_backup.tar.bz2
```

---

## node2 問題

> **初期状態**: rootパスワード不明、ネットワーク設定済み（`192.168.56.102`）、追加ディスク 2 本（`/dev/sdb` 5GB, `/dev/sdc` 3GB）

---

### 問題 1 — rootパスワードの回復

rootパスワードが不明な状態から、ブートローダーを使ってパスワードを変更せよ。

- 変更後のパスワード: `newroot`
- 再起動後、`newroot` で root ログインができること

```
手順:
1. VM コンソールで再起動
2. GRUB 画面で 'e' キーを押して編集モード
3. linux または linuxefi で始まる行の末尾に: rd.break
4. Ctrl+X で起動
5. 以下のコマンドを実行:
   mount -o remount,rw /sysroot
   chroot /sysroot
   passwd root          ← newroot を入力
   touch /.autorelabel
   exit
   exit
```

---

### 問題 2 — DNF リポジトリ設定（参考問題）

> ※ 問題 1 完了後（rootパスワード既知の状態）で実施

既存のリポジトリ設定をすべて削除し、以下の URL を新しいリポジトリとして登録せよ。

```
http://192.168.56.100/baseos
http://192.168.56.100/appstream
```

- `gpgcheck=0` で設定すること
- 設定完了後、`telnet` パッケージをインストールして確認

```bash
# ヒント
rm -rf /etc/yum.repos.d/*.repo
dnf config-manager --add-repo=http://192.168.56.100/baseos
echo 'gpgcheck=0' >> /etc/yum.repos.d/*.repo
# ... appstream も同様
dnf -y install telnet
```

---

### 問題 3 — LVM 構成

`/dev/sdb` を使用して以下の LVM 構成を作成せよ。

| ステップ | 内容 |
|---------|------|
| 1 | `/dev/sdb` に PV（物理ボリューム）を作成 |
| 2 | VG 名 `vg_data`、PE サイズ `16MB` で VG を作成 |
| 3 | LV 名 `lv_web`、サイズ `2GB` で LV を作成 |
| 4 | `lv_web` を **XFS** でフォーマット |
| 5 | `/web` ディレクトリに**永続マウント**（再起動後も維持） |
| 6 | `lv_web` を `3GB` に**拡張**（マウントしたまま、XFS 拡張含む） |

```bash
# ヒント
lsblk                                        # デバイス名確認
pvcreate /dev/sdb
vgcreate -s 16M vg_data /dev/sdb
lvcreate -L 2G -n lv_web vg_data
mkfs.xfs /dev/vg_data/lv_web
mkdir /web
echo '/dev/vg_data/lv_web /web xfs defaults 0 0' >> /etc/fstab
mount -a
df -h /web                                   # 確認

# 拡張
lvextend -L 3G /dev/vg_data/lv_web
xfs_growfs /web                              # XFS はオンラインで拡張可能
df -h /web                                   # 3GB になっていること確認
```

---

### 問題 4 — SWAP の追加

`/dev/sdc` を使用してスワップ領域を追加せよ。

1. `fdisk` で `/dev/sdc` に **1GB** のスワップパーティション（タイプ: `82` Linux swap）を作成
2. `mkswap` でスワップ初期化
3. `swapon` でスワップ有効化
4. `/etc/fstab` に追記し、**再起動後も自動有効化**されること

```bash
# ヒント
lsblk                         # /dev/sdc 確認
fdisk /dev/sdc
  n → p → 1 → Enter → +1G → t → 82 → w

mkswap /dev/sdc1
swapon /dev/sdc1
swapon --show                 # 確認

echo '/dev/sdc1 swap swap defaults 0 0' >> /etc/fstab
```

---

### 問題 5 — コンテナ管理（Podman）

`tester` ユーザーとして（rootless）以下のコンテナ設定を行え。

1. `docker.io/library/nginx:latest` イメージを取得
2. 以下の設定でコンテナを起動:
   - コンテナ名: `web`
   - ホストポート `8080` → コンテナポート `80`
   - バックグラウンド実行
3. **systemd ユーザーサービス**として自動起動を設定
4. OS 再起動後もコンテナが自動起動すること（`loginctl enable-linger`）

```bash
# tester ユーザーで実行
podman pull docker.io/library/nginx:latest
podman run -d --name web -p 8080:80 nginx

# systemd サービス生成
mkdir -p ~/.config/systemd/user
podman generate systemd --name web --files --new
mv container-web.service ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now container-web.service

# linger 設定 (root で実行)
sudo loginctl enable-linger tester

# 確認
podman ps
curl http://localhost:8080
```

---

## 採点

```bash
# node1 採点
bash shells/score_node1.sh

# node2 採点 (新しいrootパスワードを引数で渡す)
bash shells/score_node2.sh newroot
```
