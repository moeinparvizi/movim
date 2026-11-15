#!/bin/bash
set -Eeuo pipefail

pause_on_failure() {
  status=$?
  if [ "$status" -ne 0 ]; then
    printf '\nInstallation stopped (exit %s). Review the message above.\n' "$status" >&2
    read -r -p 'Press Enter to close. ' _ || true
  fi
}
trap pause_on_failure EXIT

if [ "$(uname -s)" != "Darwin" ]; then
  echo 'This installer must run on macOS.' >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SOURCE="$SCRIPT_DIR/config"
if [ ! -f "$CONFIG_SOURCE/init.lua" ] || [ ! -f "$CONFIG_SOURCE/lazy-lock.json" ]; then
  echo 'The config folder is missing. Extract the entire ZIP before running Install.command.' >&2
  exit 1
fi

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v brew >/dev/null 2>&1; then
  echo 'Installing Homebrew. Follow its prompts; an administrator password may be required.'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if ! command -v brew >/dev/null 2>&1; then
  echo 'Homebrew is not available. Complete its setup, then run this installer again.' >&2
  exit 1
fi
eval "$(brew shellenv)"

echo 'Installing Neovim, Node.js, ripgrep, fd and lazygit...'
brew install neovim node ripgrep fd lazygit git
if [ -d "$CONFIG_SOURCE/fonts" ]; then
  mkdir -p "$HOME/Library/Fonts"
  for font in "$CONFIG_SOURCE"/fonts/*.ttf; do
    [ -f "$font" ] || continue
    [ -e "$HOME/Library/Fonts/$(basename "$font")" ] || cp "$font" "$HOME/Library/Fonts/"
  done
fi

CONFIG_DIR="$HOME/.config/web-neovim"
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/Applications"
if [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
  BACKUP="$CONFIG_DIR.backup.$(date +%Y%m%d%H%M%S)"
  if [ -e "$BACKUP" ] || [ -L "$BACKUP" ]; then
    echo "Backup already exists: $BACKUP. Run the installer again in a moment." >&2
    exit 1
  fi
  mv "$CONFIG_DIR" "$BACKUP"
  echo "Previous movim config saved to: $BACKUP"
fi
mkdir -p "$CONFIG_DIR"
cp -R "$CONFIG_SOURCE/." "$CONFIG_DIR/"

cat > "$HOME/.local/bin/movim" <<'LAUNCHER'
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export NVIM_APPNAME=web-neovim
if [ "$#" -gt 0 ] && [ -d "$1" ]; then
  cd "$1"
  shift
fi
exec nvim "$@"
LAUNCHER
chmod 755 "$HOME/.local/bin/movim"

# Keep the previous project name usable after upgrading.
cat > "$HOME/.local/bin/nemovim" <<'COMPAT'
#!/bin/bash
exec "$HOME/.local/bin/movim" "$@"
COMPAT
chmod 755 "$HOME/.local/bin/nemovim"

# Keep the old command working for existing installations.
cat > "$HOME/.local/bin/web-nvim" <<'COMPAT'
#!/bin/bash
exec "$HOME/.local/bin/movim" "$@"
COMPAT
chmod 755 "$HOME/.local/bin/web-nvim"

cat > "$HOME/Applications/movim.command" <<'SHORTCUT'
#!/bin/bash
exec "$HOME/.local/bin/movim" "$@"
SHORTCUT
chmod 755 "$HOME/Applications/movim.command"

PROFILE="$HOME/.zprofile"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH" # Web Neovim'
touch "$PROFILE"
if ! grep -Fqx "$PATH_LINE" "$PROFILE"; then
  printf '\n%s\n' "$PATH_LINE" >> "$PROFILE"
fi

echo 'Installing Neovim plugins. This may take several minutes...'
NVIM_APPNAME=web-neovim nvim --headless '+Lazy! install' '+Lazy! restore' '+qa'

echo
echo 'Installation complete. Open a new Terminal and run: movim'
echo 'You can also open Applications/movim.command.'
echo 'Select DejaVuSansM Nerd Font Mono in your terminal settings for Persian glyphs and icons.'
read -r -p 'Press Enter to close. ' _ || true
