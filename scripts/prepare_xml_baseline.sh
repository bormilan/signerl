#!/usr/bin/env bash
set -euo pipefail

# Historical test oracle only; never added to Signerl's production code path.
revision=5927e41bab8674b875c51df1a1ec956d42676992
cd "$(dirname "$0")/.."
baseline=priv/xml-baseline
if [[ ! -d "$baseline/.git" ]]; then
  mkdir -p "$baseline"
  git init "$baseline"
  git -C "$baseline" remote add origin https://github.com/bormilan/signerl.git
  git -C "$baseline" fetch --depth 1 origin "$revision"
  git -C "$baseline" -c core.autocrlf=false checkout --detach "$revision"
fi
[[ "$(git -C "$baseline" rev-parse HEAD)" == "$revision" ]]
[[ -z "$(git -C "$baseline" status --porcelain)" ]]
printf 'XML comparison baseline: %s\n' "$revision"
