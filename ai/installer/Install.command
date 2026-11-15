#!/bin/bash
set -Eeuo pipefail
if [ "$(uname -s)" != Darwin ]; then echo 'This installer requires macOS.' >&2; exit 1; fi
SOURCE="$(cd "$(dirname "$0")" && pwd)/config"
test -f "$SOURCE/ai/runtime/package-lock.json" || { echo 'Extract the entire AI archive first.'; exit 1; }
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v brew >/dev/null; then echo 'Install Homebrew from brew.sh, then rerun this installer.'; exit 1; fi
eval "$(brew shellenv)"
brew install neovim node ripgrep fd lazygit git
TARGET="$HOME/.config/movim-ai"
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/Applications" "$HOME/Library/Fonts"
if [ -e "$TARGET" ]; then
  BACKUP="$TARGET.backup.$(date +%Y%m%d%H%M%S)"
  test ! -e "$BACKUP" || { echo 'Backup already exists; retry later.'; exit 1; }
  mv "$TARGET" "$BACKUP"
fi
mkdir -p "$TARGET"
cp -R "$SOURCE/." "$TARGET/"
for font in "$TARGET"/fonts/*.ttf; do
  [ -f "$font" ] || continue
  [ -e "$HOME/Library/Fonts/$(basename "$font")" ] || cp "$font" "$HOME/Library/Fonts/"
done
(cd "$TARGET/ai/runtime" && npm ci --ignore-scripts --no-audit --no-fund)
cat > "$HOME/.local/bin/movim-ai" <<'LAUNCHER'
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export NVIM_APPNAME=movim-ai
if [ "$#" -gt 0 ] && [ -d "$1" ]; then cd "$1"; shift; fi
exec nvim "$@"
LAUNCHER
chmod 755 "$HOME/.local/bin/movim-ai"
cat > "$HOME/Applications/movim-ai.command" <<'SHORTCUT'
#!/bin/bash
exec "$HOME/.local/bin/movim-ai" "$@"
SHORTCUT
chmod 755 "$HOME/Applications/movim-ai.command"
NVIM_APPNAME=movim-ai nvim --headless '+Lazy! install' '+Lazy! restore' '+qa'
echo 'Installed separately. Run ~/.local/bin/movim-ai, then :AIConfigure.'
echo 'Set your provider API key in the named environment variable before starting the editor.'
read -r -p 'Press Enter to close. ' _ || true
