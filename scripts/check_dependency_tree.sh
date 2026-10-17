#!/usr/bin/env bash
set -euo pipefail

[[ $# == 1 ]] || { echo 'Usage: check_dependency_tree.sh DEPENDENCY_DIRECTORY' >&2; exit 1; }
dependency_dir=$1
# Ignore host-wide exclude rules. Tracked changes always fail, including ebin files.
if [[ -n "$(git -c core.excludesFile= -C "$dependency_dir" status --porcelain --untracked-files=no)" ]]; then
  echo 'Dependency tracked files changed:' >&2
  git -c core.excludesFile= -C "$dependency_dir" status --short --untracked-files=no >&2
  exit 1
fi
# A Git dependency is compiled in place; xmlan's pinned ignore file omits ebin/.
# Only ordinary compiler output may be untracked outside repository ignore rules.
unexpected_files=$(git -c core.excludesFile= -C "$dependency_dir" ls-files --others --exclude-standard -- . \
  ':(top,glob,exclude)ebin/*.beam' ':(top,glob,exclude)ebin/*.app')
if [[ -n "$unexpected_files" ]]; then
  echo 'Dependency has unexpected untracked files:' >&2
  printf '%s\n' "$unexpected_files" >&2
  exit 1
fi
