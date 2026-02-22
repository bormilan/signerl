#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OTP26_IMAGE="${OTP26_IMAGE:-erlang:26.2.5}"
OTP27_IMAGE="${OTP27_IMAGE:-erlang:27.3.4}"
OTP28_IMAGE="${OTP28_IMAGE:-erlang:28}"

usage() {
    cat <<'USAGE'
Usage: scripts/ci_local_docker.sh [--otp <version>]...

Runs local CI-equivalent checks in Docker for selected OTP versions.
Defaults to OTP 26, 27, and 28.

Options:
  --otp <version>  Run only selected OTP version (26, 27, or 28). Can be repeated.
  -h, --help       Show this help text.
USAGE
}

selected=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --otp)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for --otp" >&2
                exit 1
            fi
            selected+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ ${#selected[@]} -eq 0 ]]; then
    selected=(26 27 28)
fi

image_for() {
    case "$1" in
        26) echo "$OTP26_IMAGE" ;;
        27) echo "$OTP27_IMAGE" ;;
        28) echo "$OTP28_IMAGE" ;;
        *)
            echo "Unsupported OTP version: $1 (expected 26, 27, or 28)" >&2
            exit 1
            ;;
    esac
}

prepare_volume_permissions() {
    local image="$1"
    local uid="$2"
    local gid="$3"
    local rebar_vol="$4"
    local build_vol="$5"

    docker run --rm \
        -v "${rebar_vol}:/home/runner/.cache/rebar3" \
        -v "${build_vol}:/workspace/_build" \
        "$image" \
        bash -lc "mkdir -p /home/runner/.cache/rebar3 /workspace/_build && chown -R ${uid}:${gid} /home/runner /workspace/_build"
}

run_for_otp() {
    local otp="$1"
    local image="$2"
    local uid
    local gid
    uid="$(id -u)"
    gid="$(id -g)"
    local rebar_vol="signerl_rebar3_cache_otp${otp}"
    local build_vol="signerl_build_cache_otp${otp}"

    echo
    echo "=== OTP ${otp} (${image}) ==="

    docker volume create "$rebar_vol" >/dev/null
    docker volume create "$build_vol" >/dev/null
    prepare_volume_permissions "$image" "$uid" "$gid" "$rebar_vol" "$build_vol"

    docker run --rm \
        --user "${uid}:${gid}" \
        -e HOME=/home/runner \
        -v "${PROJECT_ROOT}:/workspace" \
        -v "${rebar_vol}:/home/runner/.cache/rebar3" \
        -v "${build_vol}:/workspace/_build" \
        -w /workspace \
        "$image" \
        bash -lc 'set -euo pipefail; scripts/gen_certs.sh; rebar3 test; rebar3 lint; rebar3 dialyzer'
}

for otp in "${selected[@]}"; do
    run_for_otp "$otp" "$(image_for "$otp")"
done
