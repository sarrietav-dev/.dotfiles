#!/usr/bin/env bash
# Idempotent standalone installer; also discovered by install/install.sh.
set -euo pipefail
set +x
umask 077

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$DOTFILES_DIR/books-sync"
STATE="$HOME/.local/state/books-sync"
HELPER="$PACKAGE/.local/lib/books-sync/config.py"

for dependency in rclone python3 flock; do
  if ! command -v "$dependency" >/dev/null; then
    case "$dependency" in
      rclone) package=rclone ;;
      python3) package=python ;;
      flock) package=util-linux ;;
    esac
    omarchy pkg add "$package"
  fi
done
if ! command -v op >/dev/null; then
  omarchy pkg aur add 1password-cli
fi
systemctl --user show-environment >/dev/null
mkdir -p "$STATE"
exec 9>"$STATE/setup.lock"
flock -n 9 || { printf 'Books sync setup is already running.\n' >&2; exit 1; }

timer_was_active=false
systemctl --user is-active --quiet books-sync.timer && timer_was_active=true
restore_timer() {
  local result=$?
  if [[ "$result" != 0 && "$timer_was_active" == true ]]; then
    if python3 "$HELPER" validate >/dev/null 2>&1; then
      systemctl --user daemon-reload
      systemctl --user start books-sync.timer
    else
      printf 'Setup incomplete; the timer is stopped. Fix the reported issue and rerun this script.\n' >&2
    fi
  fi
  return "$result"
}
trap restore_timer EXIT
for unit in books-sync.timer books-sync.service; do
  if [[ "$(systemctl --user show "$unit" -p LoadState --value)" != not-found ]]; then
    systemctl --user stop "$unit"
  fi
done
exec 8>"$STATE/run.lock"
flock -n 8 || { printf 'A manual Books sync is running; rerun setup when it finishes.\n' >&2; exit 1; }

# Link only this package's known files. Preserve replaced standalone files.
paths=(
  .local/bin/books-sync
  .local/bin/books-sync-authorize
  .local/lib/books-sync/config.py
  .config/books-sync/filters.txt
  .config/systemd/user/books-sync.service
  .config/systemd/user/books-sync.timer
)
backup="$STATE/setup-backups/$(date -u +%Y%m%dT%H%M%S)-$$"
for path in "${paths[@]}"; do
  source="$PACKAGE/$path"
  target="$HOME/$path"
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    continue
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$backup/$(dirname "$path")"
    mv "$target" "$backup/$path"
  fi
  ln -s "$source" "$target"
done
status="$(python3 "$HELPER" configure)"
if [[ "$status" == authorize ]]; then
  printf 'Authorize Google Drive in the browser. OAuth credentials were loaded from 1Password.\n'
  rclone config reconnect books-drive: --config "$HOME/.config/rclone/rclone.conf"
else
  printf 'Existing Google authorization preserved.\n'
fi
python3 "$HELPER" validate
rclone lsd books-drive: --config "$HOME/.config/rclone/rclone.conf" >/dev/null
mkdir -p "$HOME/Documents/Books"
flock -u 8
exec 8>&-

if [[ -f "$STATE/initialized" ]]; then
  printf 'Existing sync baseline preserved; running an incremental sync.\n'
  "$HOME/.local/bin/books-sync" run
  python3 "$HELPER" record
else
  printf 'Previewing and initializing the first merge (newer wins; overwritten versions are backed up).\n'
  "$HOME/.local/bin/books-sync" preview
  "$HOME/.local/bin/books-sync" initialize
fi
systemd-analyze --user verify "$HOME/.config/systemd/user/books-sync.service" \
  "$HOME/.config/systemd/user/books-sync.timer"
systemctl --user daemon-reload
systemctl --user enable --now books-sync.timer
printf 'Books sync installed: ~/Documents/Books <-> Google Drive, every 15 minutes.\n'
systemctl --user list-timers books-sync.timer --no-pager
