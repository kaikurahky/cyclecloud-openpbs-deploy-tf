#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
INFRA_DIR="$ROOT_DIR/infra"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

load_env() {
  local env_file=$1
  [[ -f "$env_file" ]] || die "Config not found: $env_file (copy the .example first)"
  set -a
  source "$env_file"
  set +a
}

load_infra_config() {
  load_env "${1:-$ROOT_DIR/config/cyclecloud.env}"
  : "${TF_VAR_subscription_id:?Set TF_VAR_subscription_id}"
  : "${TF_VAR_location:?Set TF_VAR_location}"
  : "${TF_VAR_name_prefix:?Set TF_VAR_name_prefix}"
  : "${TF_VAR_storage_account_name:?Set TF_VAR_storage_account_name}"
  : "${TF_VAR_cyclecloud_image_urn:?Set TF_VAR_cyclecloud_image_urn}"
  [[ "$TF_VAR_subscription_id" != "00000000-0000-0000-0000-000000000000" ]] || die "Replace the example subscription ID"
  [[ "$TF_VAR_storage_account_name" != "replacewithuniquename" ]] || die "Set a unique storage account name"
  [[ -f "${SSH_PUBLIC_KEY_FILE:-}" ]] || die "SSH public key file not found"
  TF_VAR_ssh_public_key=$(< "$SSH_PUBLIC_KEY_FILE")
  export TF_VAR_ssh_public_key
  [[ "$TF_VAR_ssh_public_key" == ssh-rsa\ * || "$TF_VAR_ssh_public_key" == ssh-ed25519\ * ]] || die "Only an SSH public key is allowed"
  export ARM_SUBSCRIPTION_ID="$TF_VAR_subscription_id"
}