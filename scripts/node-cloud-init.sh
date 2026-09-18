#!/usr/bin/env bash
set -euo pipefail
dnf install -y nfs-utils
nfsconf --file /etc/idmapd.conf --set General Domain defaultv4iddomain.com
nfsidmap -c