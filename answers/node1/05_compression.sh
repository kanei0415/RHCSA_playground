#!/bin/bash
# [node1] 問題5: 圧縮・アーカイブ (idempotent — archives are overwritten)
set -euo pipefail

echo ">>> Creating /tmp/log_backup.tar.gz (/var/log, gzip)"
tar czf /tmp/log_backup.tar.gz /var/log 2>/dev/null
echo "    Created: $(ls -lh /tmp/log_backup.tar.gz | awk '{print $5, $9}')"

echo ">>> Creating /tmp/etc_backup.tar.bz2 (/etc, bzip2)"
tar cjf /tmp/etc_backup.tar.bz2 /etc 2>/dev/null
echo "    Created: $(ls -lh /tmp/etc_backup.tar.bz2 | awk '{print $5, $9}')"

echo ">>> Contents of /tmp/etc_backup.tar.bz2 (first 10 entries):"
tar tjf /tmp/etc_backup.tar.bz2 | head -10
echo "    ..."
