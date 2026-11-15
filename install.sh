#!/usr/bin/env bash
# Install from a source checkout through the maintained platform installer.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/config"
cp "$root/init.lua" "$root/lazy-lock.json" "$root/README.md" "$root/LICENSE" "$root/CHANGELOG.md" "$staging/config/"
cp -R "$root/lua" "$root/colors" "$root/keymap" "$root/docs" "$root/fonts" "$staging/config/"
mkdir -p "$staging/config/site/docs-en"
cp "$root/site/docs-en/README.md" "$staging/config/site/docs-en/"
case "$(uname -s)" in
  Darwin) cp "$root/installer/macos/Install.command" "$staging/Install.command"; bash "$staging/Install.command" ;;
  Linux) cp "$root/installer/linux/Install.sh" "$staging/Install.sh"; bash "$staging/Install.sh" ;;
  *) echo 'Use movim-Setup.exe on Windows.' >&2; exit 1 ;;
esac
