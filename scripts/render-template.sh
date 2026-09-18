#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'Usage: bash %s UPSTREAM_TEMPLATE PROJECT_VERSION\n' "$0" >&2
  exit 2
fi

template=$1
version=$2
[[ -f "$template" ]] || { printf 'Template not found: %s\n' "$template" >&2; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid project version\n' >&2; exit 1; }

awk -v version="$version" '
  /\[\[\[cluster-init cyclecloud\/pbspro:(default|server|login|execute)\]\]\]/ {
    sub(/cyclecloud\/pbspro:/, "pbspro:")
    sub(/\]\]\]/, ":" version "]]]")
    count++
  }
  { lines[NR] = $0 }
  END {
    if (count != 4) {
      print "Expected exactly four official pbspro cluster-init references" > "/dev/stderr"
      exit 1
    }
    for (line = 1; line <= NR; line++) print lines[line]
  }
' "$template"