#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for script in "$root"/scripts/*.sh "$root"/tests/*.sh "$root"/examples/*.pbs; do
  bash -n "$script"
done
shellcheck -x -P "$root/scripts" -e SC1090,SC1091,SC2034 "$root"/scripts/*.sh "$root"/tests/*.sh "$root"/examples/*.pbs
bash "$root/tests/scripts.sh"
terraform -chdir="$root/infra" fmt -check -recursive
terraform -chdir="$root/infra" init -backend=false -input=false
terraform -chdir="$root/infra" validate
terraform -chdir="$root/infra" test