#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-$root/../movim-linux.tar.gz}"
node "$root/installer/manifest.cjs"
node "$root/ai/manifest.cjs"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/movim-linux/config"
cp "$root/installer/linux/Install.sh" "$root/installer/linux/README.txt" "$staging/movim-linux/"
cp "$root/init.lua" "$root/lazy-lock.json" "$root/README.md" "$root/LICENSE" "$root/CHANGELOG.md" "$root/release.json" "$staging/movim-linux/config/"
cp -R "$root/lua" "$root/colors" "$root/keymap" "$root/docs" "$root/fonts" "$staging/movim-linux/config/"
mkdir -p "$staging/movim-linux/config/ai/runtime"
cp -R "$root/ai/lua" "$staging/movim-linux/config/ai/"
cp "$root/ai/README.md" "$staging/movim-linux/config/ai/"
cp "$root/ai/runtime/package.json" "$root/ai/runtime/package-lock.json" "$staging/movim-linux/config/ai/runtime/"
cp "$root/ai/dist/ai-release.json" "$staging/movim-linux/config/ai/"
mkdir -p "$staging/movim-linux/config/site/docs-en"
cp "$root/site/docs-en/README.md" "$staging/movim-linux/config/site/docs-en/"
chmod 755 "$staging/movim-linux/Install.sh"
tar -czf "$output" -C "$staging" movim-linux
printf 'Created %s\n' "$output"
