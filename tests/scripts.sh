#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

# shellcheck disable=SC2317
(
  az() {
    case "$1 $2" in
      'account show') printf 'test account\r\n' ;;
      'provider show') printf '%s\r\n' "${TEST_PROVIDER_STATE:-Registered}" ;;
      'vm image')
        if [[ "$3" == terms ]]; then
          printf '%s\r\n' "${TEST_TERMS_ACCEPTED:-true}"
        else
          printf '{"dataDiskImages":[{"lun":0}]}\r\n'
        fi
        ;;
      *) return 1 ;;
    esac
  }
  terraform() { return 0; }
  export -f az terraform
  sed -e 's/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/' \
    -e 's/replacewithuniquename/pbsteststorage/' \
    "$root/config/cyclecloud.env.example" > "$temporary/infra.env"
  printf 'ssh-rsa test-only-not-a-real-key\n' > "$temporary/test.pub"
  printf '\nSSH_PUBLIC_KEY_FILE="%s"\n' "$temporary/test.pub" >> "$temporary/infra.env"
  bash "$root/scripts/preflight.sh" "$temporary/infra.env"
  if TEST_PROVIDER_STATE=Registering bash "$root/scripts/preflight.sh" "$temporary/infra.env"; then exit 1; fi
  if TEST_TERMS_ACCEPTED=false bash "$root/scripts/preflight.sh" "$temporary/infra.env"; then exit 1; fi
)

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
printf 'PASS: CRLF preflight, template pinning, parameter rendering, invalid inputs and upstream parameter names\n'