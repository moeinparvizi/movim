#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-$root/../movim-linux.tar.gz}"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/movim-linux/config"
cp "$root/installer/linux/Install.sh" "$root/installer/linux/README.txt" "$staging/movim-linux/"
cp "$root/init.lua" "$root/lazy-lock.json" "$root/README.md" "$root/LICENSE" "$staging/movim-linux/config/"
cp -R "$root/lua" "$root/keymap" "$root/docs" "$staging/movim-linux/config/"
chmod 755 "$staging/movim-linux/Install.sh"
tar -czf "$output" -C "$staging" movim-linux
printf 'Created %s\n' "$output"
