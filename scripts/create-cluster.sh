#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -eq 2 ]] || die "Usage: bash $0 CLUSTER_NAME PARAMETERS.json"
require_command cyclecloud
require_command jq
cluster=$1
parameters=$2
[[ "$cluster" =~ ^[a-z][a-z0-9-]{2,29}$ ]] || die "Use 3-30 lowercase letters, digits and hyphens for the cluster name"
[[ "$parameters" == *.json ]] || die "Parameters must have a .json extension"
[[ -f "$ROOT_DIR/work/openpbs.txt" ]] || die "Run prepare-openpbs.sh LOCKER_NAME first"
jq -e '.Autoscale == true and .UsePublicNetwork == false and .ExecuteNodesPublic == false and (.MaxExecuteCoreCount > 0)' "$parameters" >/dev/null
cyclecloud import_cluster "$cluster" -c OpenPBS -f "$ROOT_DIR/work/openpbs.txt" -p "$parameters"
printf 'Cluster created, NOT started. Review networking, storage and Cloud-init in the UI.\n'
if jq -e '.AdditionalNAS == true' "$parameters" >/dev/null; then
  printf 'ANF enabled: apply scripts/node-cloud-init.sh to ALL nodes before starting.\n'
fi
printf 'After review: cyclecloud start_cluster %s\n' "$cluster"