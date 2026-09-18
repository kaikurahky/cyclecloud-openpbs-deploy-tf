#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
load_infra_config "${1:-$ROOT_DIR/config/cyclecloud.env}"
for tool in az terraform jq; do require_command "$tool"; done

az account show --subscription "$TF_VAR_subscription_id" --query '{name:name,state:state}' -o table
providers=(Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.ManagedIdentity Microsoft.Resources Microsoft.MarketplaceOrdering)
if [[ "${TF_VAR_enable_anf:-true}" == true ]]; then providers+=(Microsoft.NetApp); fi
for provider in "${providers[@]}"; do
  state=$(az provider show --namespace "$provider" --subscription "$TF_VAR_subscription_id" --query registrationState -o tsv)
  [[ "$state" == Registered ]] || die "Register $provider first: az provider register --namespace $provider --subscription $TF_VAR_subscription_id --wait"
done

image=$(az vm image show --urn "$TF_VAR_cyclecloud_image_urn" --location "$TF_VAR_location" --subscription "$TF_VAR_subscription_id" -o json)
expected_luns=$(jq -c '[.dataDiskImages[]?.lun] | sort' <<< "$image")
configured_luns=$(jq -c 'sort' <<< "${TF_VAR_image_data_disk_luns:-[0]}")
[[ "$expected_luns" == "$configured_luns" ]] || die "Image requires data disk LUNs $expected_luns; update TF_VAR_image_data_disk_luns"
terms=$(az vm image terms show --urn "$TF_VAR_cyclecloud_image_urn" --subscription "$TF_VAR_subscription_id" --query accepted -o tsv)
[[ "${terms,,}" == true ]] || die "Review and accept CycleCloud Marketplace terms first (see docs/deployment-guide.md)"
printf 'Preflight passed. Still check quota, policy, VM capacity, networking and costs before applying.\n'