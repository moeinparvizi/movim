#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Linux ]; then echo 'This installer is for Linux.' >&2; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/config"
if [ ! -f "$SOURCE/init.lua" ] || [ ! -f "$SOURCE/lazy-lock.json" ]; then
  echo 'Extract the entire movim-linux archive before running this installer.' >&2; exit 1
fi
for executable in nvim git node npm rg curl; do
  if ! command -v "$executable" >/dev/null 2>&1; then echo "Missing prerequisite: $executable. Install it using your Linux distribution, then retry." >&2; exit 1; fi
done
if ! nvim --headless -u NONE -c "lua if vim.fn.has('nvim-0.11') == 0 then vim.cmd.cquit(1) end" -c 'qa' >/dev/null 2>&1; then
  echo 'Neovim 0.11 or newer is required.' >&2; exit 1
fi
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_DIR="$CONFIG_HOME/movim"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$CONFIG_HOME" "$BIN_DIR"
if [ -f "$CONFIG_DIR/release.json" ]; then
  node "$SOURCE/lua/utils/update-engine.cjs" local "$CONFIG_DIR" "$SOURCE"
elif [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
  BACKUP="$CONFIG_DIR.backup.$(date +%Y%m%d%H%M%S)"
  if [ -e "$BACKUP" ] || [ -L "$BACKUP" ]; then echo 'Backup already exists; retry shortly.' >&2; exit 1; fi
  mv "$CONFIG_DIR" "$BACKUP"
  printf 'Previous movim configuration backed up to %s\n' "$BACKUP"
fi
if [ ! -f "$CONFIG_DIR/release.json" ]; then
  mkdir -p "$CONFIG_DIR"
  cp -R "$SOURCE/." "$CONFIG_DIR/"
fi
if [ -d "$SOURCE/fonts" ]; then
  FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/movim"
  mkdir -p "$FONT_DIR"
  for font in "$SOURCE"/fonts/*.ttf; do
    [ -f "$font" ] || continue
    [ -e "$FONT_DIR/$(basename "$font")" ] || cp "$font" "$FONT_DIR/"
  done
  if command -v fc-cache >/dev/null 2>&1; then fc-cache -f "$FONT_DIR" || true; fi
fi
cat > "$BIN_DIR/movim" <<'LAUNCHER'
#!/usr/bin/env bash
export NVIM_APPNAME=movim
if [ "$#" -gt 0 ] && [ -d "$1" ]; then cd "$1"; export MOVIM_PROJECT_DIR="$PWD"; shift; fi
exec nvim "$@"
LAUNCHER
chmod 755 "$BIN_DIR/movim"
echo 'Installed. Run ~/.local/bin/movim (add ~/.local/bin to PATH if needed).'
echo 'Select DejaVuSansM Nerd Font Mono in your terminal settings for Persian glyphs and icons.'
echo 'The first run installs plugins and language tools; Git and an internet connection are required.'
