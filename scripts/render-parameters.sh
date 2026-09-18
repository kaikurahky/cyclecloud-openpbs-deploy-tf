#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -ge 1 && $# -le 2 ]] || die "Usage: bash $0 TERRAFORM_OUTPUTS.json [OPENPBS.env]"
require_command jq
outputs=$1
load_env "${2:-$ROOT_DIR/config/openpbs.env}"
for name in PBS_CREDENTIALS PBS_REGION PBS_SERVER_VM_SIZE PBS_EXECUTE_VM_SIZE PBS_IMAGE PBS_VERSION; do
  [[ -n "${!name:-}" ]] || die "Missing $name"
done
[[ "${PBS_MAX_CORES:-}" =~ ^[1-9][0-9]*$ ]] || die "PBS_MAX_CORES must be a positive integer"
[[ "${PBS_USE_ANF:-}" == true || "${PBS_USE_ANF:-}" == false ]] || die "PBS_USE_ANF must be true or false"
[[ "$PBS_VERSION" == 22.05.11-0 || "$PBS_VERSION" == 20.0.1-0 ]] || die "Use an OpenPBS EL8 version from the pinned project"
jq -e '(.cluster_subnet_cyclecloud.value | type == "string" and length > 0) and (.locker_identity_id.value | type == "string" and startswith("/subscriptions/"))' "$outputs" >/dev/null
if [[ "$PBS_USE_ANF" == true ]]; then
  jq -e '(.anf_mount_ip.value | type == "string" and length > 0) and (.anf_export_path.value | type == "string" and startswith("/"))' "$outputs" >/dev/null
fi
jq --arg credentials "$PBS_CREDENTIALS" --arg region "$PBS_REGION" \
  --arg server "$PBS_SERVER_VM_SIZE" --arg execute "$PBS_EXECUTE_VM_SIZE" \
  --arg image "$PBS_IMAGE" --arg version "$PBS_VERSION" \
  --argjson cores "$PBS_MAX_CORES" --argjson anf "$PBS_USE_ANF" '
  {
    Credentials: $credentials,
    Region: $region,
    SubnetId: .cluster_subnet_cyclecloud.value,
    ManagedIdentity: .locker_identity_id.value,
    serverMachineType: $server,
    ExecuteMachineType: [$execute],
    SchedulerImageName: $image,
    ImageName: $image,
    PBSVersion: $version,
    Autoscale: true,
    AzpbsCronMethod: "cron",
    MaxExecuteCoreCount: $cores,
    UseLowPrio: false,
    UsePublicNetwork: false,
    ExecuteNodesPublic: false,
    ReturnProxy: true,
    NumberLoginNodes: 0,
    NFSType: "Builtin",
    NFSSchedDisable: false,
    FilesystemSize: 100,
    AdditionalNAS: $anf
  } + (if $anf then {
    AdditonalNFSAddress: .anf_mount_ip.value,
    AdditionalNFSMountPoint: "/data",
    AdditionalNFSExportPath: .anf_export_path.value,
    AdditionalNFSMountOptions: "vers=4.1,sec=sys,hard,rsize=1048576,wsize=1048576,timeo=600,retrans=2"
  } else {} end)
' "$outputs"