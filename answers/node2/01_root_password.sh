#!/bin/bash
# [node2] 問題1: rootパスワード回復
#
# 実際の試験では rd.break を使用 (コンソール操作が必要):
#   1. 起動時 GRUB 画面で 'e' キー
#   2. linux/linuxefi 行末に: rd.break
#   3. Ctrl+X で起動
#   4. mount -o remount,rw /sysroot
#   5. chroot /sysroot
#   6. passwd root          ← "newroot" を入力
#   7. touch /.autorelabel
#   8. exit; exit
#
# このシミュレーターでは tester の NOPASSWD sudo を使って同等操作を実施
set -euo pipefail

NEW_PASS="newroot"

echo ">>> Changing root password to '${NEW_PASS}'"
echo "${NEW_PASS}" | passwd --stdin root

echo ">>> Verify (shadow file modification time):"
ls -la /etc/shadow

echo ""
echo "NOTE: 実試験では rd.break method を使用すること"
echo "      (sudo passwd root は試験環境では使えません)"
