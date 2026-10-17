#!/usr/bin/env bash
set -euo pipefail

# Supply an immutable published Signerl commit and a new consumer directory.
[[ $# == 2 && "$1" =~ ^[0-9a-f]{40}$ ]] || { echo 'Usage: check_external_consumer.sh SIGNERL_SHA NEW_DIRECTORY' >&2; exit 1; }
revision=$1
consumer_dir=$2
source_root=$(cd "$(dirname "$0")/.." && pwd)
[[ ! -e "$consumer_dir" ]] || { echo 'Consumer directory must not already exist' >&2; exit 1; }
mkdir -p "$consumer_dir/src" "$consumer_dir/global-empty"
consumer_dir=$(cd "$consumer_dir" && pwd)
cp "$source_root/test/xmlan_contract_consumer.erl" "$source_root/test/signerl_external_consumer.erl" "$consumer_dir/src/"
cat > "$consumer_dir/src/signerl_external.app.src" <<'APP'
{application, signerl_external, [{description, "Signerl external acceptance consumer"},
 {vsn, "0.1.0"}, {modules, []},
 {applications, [kernel, stdlib, crypto, public_key, signerl, xmlan]}]}.
APP
cat > "$consumer_dir/rebar.config" <<CONFIG
{erl_opts, [debug_info]}.
{deps, [{signerl, {git, "https://github.com/bormilan/signerl.git", {ref, "$revision"}}}]}.
CONFIG
printf '%s\n' "$revision" > "$consumer_dir/signerl.expected-ref"
unset ERL_LIBS ERL_FLAGS ERL_AFLAGS ERL_ZFLAGS REBAR_PROFILE REBAR_CONFIG REBAR_CONFIG_SCRIPT REBAR_BASE_DIR REBAR_DEPS_DIR
export REBAR_GLOBAL_CONFIG_DIR="$consumer_dir/global-empty"
export REBAR_CACHE_DIR="$consumer_dir/cache"
cd "$consumer_dir"
"${REBAR3:-rebar3}" compile
erl -noshell -enable-feature maybe_expr -pa _build/default/lib/*/ebin \
  -eval 'ok = signerl_external_consumer:run(filename:join([code:lib_dir(signerl), "test", "examples", "xmlan_migration"]), "."), halt().'
echo 'Consumer runtime assertions passed; checking fetched revisions and working trees.'
[[ "$(git -C _build/default/lib/signerl rev-parse HEAD)" == "$revision" ]] || { echo 'Signerl fetched HEAD mismatch' >&2; exit 1; }
[[ "$(git -C _build/default/lib/xmlan rev-parse HEAD)" == "$(cat xmlan.expected-ref)" ]] || { echo 'xmlan fetched HEAD mismatch' >&2; exit 1; }
[[ "$(git -C _build/default/lib/signerl remote get-url origin)" == 'https://github.com/bormilan/signerl.git' ]] || { echo 'Signerl HTTPS origin mismatch' >&2; exit 1; }
[[ "$(git -C _build/default/lib/xmlan remote get-url origin)" == 'https://github.com/bormilan/xmlan.git' ]] || { echo 'xmlan HTTPS origin mismatch' >&2; exit 1; }
[[ -z "$(git -C _build/default/lib/signerl status --porcelain)" ]] || { echo 'Signerl dependency working tree changed:' >&2; git -C _build/default/lib/signerl status --short >&2; exit 1; }
[[ -z "$(git -C _build/default/lib/xmlan status --porcelain)" ]] || { echo 'xmlan dependency working tree changed:' >&2; git -C _build/default/lib/xmlan status --short >&2; exit 1; }
"${REBAR3:-rebar3}" dialyzer
printf 'Clean HTTPS consumer passed: Signerl %s; xmlan %s\n' "$revision" "$(cat xmlan.expected-ref)"
