#!/usr/bin/env bash
# Self-hosted runner, approved fork pull requests only: give the job private copies of the build
# directory, Cargo home and rustup home, so the job never writes to the shared warm directories
# that main and merge-queue runs reuse (a build script or test from a fork could otherwise leave
# files there). The copies start as the warm state (reflinks where the filesystem has them) and
# `fork-scratch.sh --clean` deletes them at the end of the job.
# Usage: fork-scratch.sh [NAME]   NAME = the warm-target.sh directory to start the build from
#        fork-scratch.sh --clean
# This keeps shared state out of reach of ordinary writes. It is not a sandbox: fork code still
# runs as the runner's user, which is why the workflow starts it only from a `labeled` event a
# maintainer triggered, never from a push.
set -euo pipefail
base=${RUNNER_TEMP:?}/fork-scratch
if [ "${1:-}" = --clean ]; then
  rm -rf "$base"
  exit 0
fi
if [ "${GITHUB_EVENT_NAME:-}" != pull_request ]; then
  echo "fork-scratch: only for pull request runs" >&2
  exit 1
fi
name=${1:-}
rm -rf "$base"
mkdir -p "$base"
if [ -n "$name" ]; then
  warm=/home/runner/work/cargo-target/$name
  if [ -d "$warm" ]; then
    cp -a --reflink=auto "$warm" "$base/target"
  else
    mkdir -p "$base/target"
  fi
  echo "CARGO_TARGET_DIR=$base/target" >> "$GITHUB_ENV"
fi
cargo_home=${CARGO_HOME:-$HOME/.cargo}
rustup_home=${RUSTUP_HOME:-$HOME/.rustup}
mkdir -p "$base/cargo-home" "$base/rustup-home"
[ -d "$cargo_home" ] && cp -a --reflink=auto "$cargo_home/." "$base/cargo-home/"
[ -d "$rustup_home" ] && cp -a --reflink=auto "$rustup_home/." "$base/rustup-home/"
{
  echo "CARGO_HOME=$base/cargo-home"
  echo "RUSTUP_HOME=$base/rustup-home"
} >> "$GITHUB_ENV"
echo "$base/cargo-home/bin" >> "$GITHUB_PATH"
echo "fork-scratch: private copies in $base ($(du -sh "$base" | cut -f1))"
