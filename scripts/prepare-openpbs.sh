#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -eq 1 ]] || die "Usage: bash $0 LOCKER_NAME | --download-only"
locker=$1
version=2.0.26
commit=2e42f3978ccc0c68f4d20b6b97858ce32b5f38d9
project="$ROOT_DIR/work/cyclecloud-pbspro"
template="$ROOT_DIR/work/openpbs.txt"
for tool in git curl sha256sum awk; do require_command "$tool"; done
if [[ "$locker" != --download-only ]]; then require_command cyclecloud; fi
umask 077
mkdir -p "$ROOT_DIR/work"

if [[ ! -d "$project" ]]; then
  git clone --depth 1 --branch "$version" --recurse-submodules https://github.com/Azure/cyclecloud-pbspro.git "$project"
fi
[[ "$(git -C "$project" rev-parse HEAD)" == "$commit" ]] || die "Unexpected upstream commit; use a fresh work directory"
git -C "$project" diff --quiet HEAD -- || die "Upstream tracked files were modified; review them before upload"
git -C "$project" submodule update --init --recursive
mkdir -p "$project/blobs"
while read -r digest filename || [[ -n "$digest" ]]; do
  [[ "$digest" =~ ^[a-f0-9]{64}$ && "$filename" != */* ]] || die "Invalid checksum manifest"
  if [[ ! -f "$project/blobs/$filename" ]]; then
    curl --fail --location --silent --show-error --retry 3 \
      "https://github.com/Azure/cyclecloud-pbspro/releases/download/$version/$filename" \
      -o "$project/blobs/$filename.partial"
    printf '%s  %s\n' "$digest" "$project/blobs/$filename.partial" | sha256sum --check --status
    mv "$project/blobs/$filename.partial" "$project/blobs/$filename"
  fi
done < "$ROOT_DIR/config/openpbs-release.sha256"
(
  cd "$project/blobs"
  sha256sum --check "$ROOT_DIR/config/openpbs-release.sha256"
)
bash "$ROOT_DIR/scripts/render-template.sh" "$project/templates/openpbs.txt" "$version" > "$template.tmp"
mv "$template.tmp" "$template"
if [[ "$locker" == --download-only ]]; then
  printf 'Verified upstream project and template: %s\n' "$template"
  exit 0
fi
(
  cd "$project"
  cyclecloud project upload "$locker"
)
cyclecloud import_template OpenPBS-2-0-26 -c OpenPBS -f "$template"
printf 'Template imported. Configure the cluster before starting it.\n'