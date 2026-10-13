#!/usr/bin/env bash
# Idempotent standalone installer; also discovered by install/install.sh.
set -euo pipefail
umask 077

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$DOTFILES_DIR/pomodoro-sync"
PLUGIN_ID=sebas.pomodoro
PLUGIN_SOURCE="$DOTFILES_DIR/omarchy/.config/omarchy/plugins/$PLUGIN_ID"
PLUGIN_TARGET="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
STATE="$HOME/.local/state/pomodoro-sync"
RCLONE_CONFIG_FILE="$HOME/.config/rclone/rclone.conf"

for dependency in rclone sqlite3 flock; do
  if ! command -v "$dependency" >/dev/null; then
    case "$dependency" in
      rclone) package=rclone ;;
      sqlite3) package=sqlite ;;
      flock) package=util-linux ;;
    esac
    omarchy pkg add "$package"
  fi
done
systemctl --user show-environment >/dev/null
mkdir -p "$STATE"
exec 9>"$STATE/setup.lock"
flock -n 9 || { printf 'Pomodoro sync setup is already running.\n' >&2; exit 1; }

# Drive access comes from the Books sync remote.
if ! rclone listremotes --config "$RCLONE_CONFIG_FILE" 2>/dev/null | grep -qx 'books-drive:'; then
  printf 'No books-drive remote yet; running the Books sync installer first.\n'
  bash "$DOTFILES_DIR/install/install_books_sync.sh"
fi

# Link only this package's known files. Preserve replaced standalone files.
paths=(
  .local/bin/pomodoro-sync
  .config/systemd/user/pomodoro-sync.service
  .config/systemd/user/pomodoro-sync.timer
)
backup="$STATE/setup-backups/$(date -u +%Y%m%dT%H%M%S)-$$"
link() { # source target
  local source="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$backup"
    mv "$target" "$backup/$(basename "$target")"
  fi
  ln -s "$source" "$target"
}
for path in "${paths[@]}"; do
  link "$PACKAGE/$path" "$HOME/$path"
done
# Relative link, like the other stowed plugins (a plugin dir may be a symlink,
# but the shell refuses symlinks inside it).
link "../../../.dotfiles/omarchy/.config/omarchy/plugins/$PLUGIN_ID" "$PLUGIN_TARGET"
[[ -f "$PLUGIN_SOURCE/manifest.json" ]] || { printf 'Plugin source is missing: %s\n' "$PLUGIN_SOURCE" >&2; exit 1; }
omarchy plugin validate "$PLUGIN_SOURCE" >/dev/null

# Enable the widget once; the shell may not be running on a fresh install.
if omarchy-shell shell ping >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins
  enabled="$(omarchy plugin list --json | python3 -c '
import json, sys
print(any(p["id"] == sys.argv[1] and p["enabled"] for p in json.load(sys.stdin)))' "$PLUGIN_ID")"
  if [[ "$enabled" != True ]]; then
    omarchy plugin enable "$PLUGIN_ID"
  fi
else
  printf 'omarchy-shell is not running; run: omarchy plugin enable %s\n' "$PLUGIN_ID"
fi

systemd-analyze --user verify "$HOME/.config/systemd/user/pomodoro-sync.service" \
  "$HOME/.config/systemd/user/pomodoro-sync.timer"
systemctl --user daemon-reload
systemctl --user enable --now pomodoro-sync.timer

# A first sync should not fail the install: an expired Google token is common.
if ! "$HOME/.local/bin/pomodoro-sync"; then
  printf '\nPomodoro sync is installed but could not reach Drive. If the token expired, reauthorize with:\n  rclone config reconnect books-drive: --config %s\n' "$RCLONE_CONFIG_FILE" >&2
fi
printf 'Pomodoro sync installed: ~/.local/share/omarchy-pomodoro <-> Google Drive/omarchy-pomodoro, every 15 minutes.\n'
systemctl --user list-timers pomodoro-sync.timer --no-pager
