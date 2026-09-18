#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

printf '%s\n' \
  '[[[cluster-init cyclecloud/pbspro:default]]]' \
  '[[[cluster-init cyclecloud/pbspro:server]]]' \
  '[[[cluster-init cyclecloud/pbspro:login]]]' \
  '[[[cluster-init cyclecloud/pbspro:execute]]]' > "$temporary/template.txt"
bash "$root/scripts/render-template.sh" "$temporary/template.txt" 2.0.26 > "$temporary/rendered.txt"
[[ $(grep -c 'cluster-init pbspro:.*:2.0.26' "$temporary/rendered.txt") -eq 4 ]]
printf 'invalid\n' > "$temporary/invalid.txt"
if bash "$root/scripts/render-template.sh" "$temporary/invalid.txt" 2.0.26; then exit 1; fi
if bash "$root/scripts/render-template.sh" "$temporary/template.txt" invalid; then exit 1; fi

jq -n '{
  cluster_subnet_cyclecloud:{value:"rg-test/vnet-test/subnet-cluster"},
  locker_identity_id:{value:"/subscriptions/test/resourceGroups/test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/locker"},
  anf_mount_ip:{value:"10.60.50.4"},
  anf_export_path:{value:"/pbs-data"}
}' > "$temporary/outputs.json"
bash "$root/scripts/render-parameters.sh" "$temporary/outputs.json" "$root/config/openpbs.env.example" > "$temporary/parameters.json"
jq -e '.PBSVersion == "22.05.11-0" and .MaxExecuteCoreCount == 8 and .AdditonalNFSAddress == "10.60.50.4" and .UsePublicNetwork == false and .ExecuteNodesPublic == false and .NFSType == "Builtin"' "$temporary/parameters.json"
sed 's/PBS_USE_ANF=true/PBS_USE_ANF=false/' "$root/config/openpbs.env.example" > "$temporary/noanf.env"
jq '.anf_mount_ip.value = "" | .anf_export_path.value = ""' "$temporary/outputs.json" > "$temporary/noanf.json"
bash "$root/scripts/render-parameters.sh" "$temporary/noanf.json" "$temporary/noanf.env" | jq -e '.AdditionalNAS == false and (has("AdditonalNFSAddress") | not)'
if bash "$root/scripts/render-parameters.sh" "$temporary/noanf.json" "$root/config/openpbs.env.example"; then exit 1; fi
sed 's/PBS_MAX_CORES=8/PBS_MAX_CORES=0/' "$root/config/openpbs.env.example" > "$temporary/invalid.env"
if bash "$root/scripts/render-parameters.sh" "$temporary/outputs.json" "$temporary/invalid.env"; then exit 1; fi

if [[ -f "$root/work/cyclecloud-pbspro/templates/openpbs.txt" ]]; then
  while read -r parameter; do
    grep -Fq "[[[parameter $parameter]]]" "$root/work/cyclecloud-pbspro/templates/openpbs.txt"
  done < <(jq -r 'keys[]' "$temporary/parameters.json")
  bash "$root/scripts/render-template.sh" "$root/work/cyclecloud-pbspro/templates/openpbs.txt" 2.0.26 > "$temporary/upstream.txt"
fi
printf 'PASS: template pinning, parameter rendering, invalid inputs and upstream parameter names\n'