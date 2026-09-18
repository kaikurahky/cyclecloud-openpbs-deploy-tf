#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
action=${1:-}
case "$action" in plan|apply|destroy) ;; *) die "Use plan, apply or destroy" ;; esac
load_infra_config "${2:-$ROOT_DIR/config/cyclecloud.env}"
for tool in az terraform; do require_command "$tool"; done
umask 077
az account show --subscription "$TF_VAR_subscription_id" --query id -o tsv >/dev/null
terraform -chdir="$INFRA_DIR" init -input=false
terraform -chdir="$INFRA_DIR" validate

if [[ "$action" == destroy ]]; then
  printf 'Back up shared data, terminate ALL CycleCloud clusters and remove their persistent resources first.\n'
  read -r -p 'Type CLUSTERS_TERMINATED to continue: ' confirmation
  [[ "$confirmation" == CLUSTERS_TERMINATED ]] || die "Cancelled"
else
  bash "$ROOT_DIR/scripts/preflight.sh" "${2:-$ROOT_DIR/config/cyclecloud.env}"
fi
if [[ "$action" == plan ]]; then
  terraform -chdir="$INFRA_DIR" plan -input=false
else
  terraform -chdir="$INFRA_DIR" "$action"
fi