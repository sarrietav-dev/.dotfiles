#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_DIRS=(ai bash git ghostty hypr kitty nvim waybar zellij scripts)

SKIP_PACKAGES=false
for arg in "$@"; do
  [[ "$arg" == "--skip-packages" ]] && SKIP_PACKAGES=true
done

if ! command -v stow &>/dev/null; then
  echo "Installing stow..."
  sudo pacman -S --noconfirm stow
fi

echo "Stowing config directories..."
for dir in "${CONFIG_DIRS[@]}"; do
  if [[ -d "$DOTFILES_DIR/$dir" ]]; then
    echo "  stow: $dir"
    # Remove conflicting non-symlink files so dotfiles take priority
    stow --simulate --restow --dir="$DOTFILES_DIR" --target="$HOME" "$dir" 2>&1 \
      | grep -oP "(?<=existing target )\S+(?= since neither)" \
      | while IFS= read -r conflict; do
          echo "    removing conflict: $HOME/$conflict"
          rm -rf "$HOME/$conflict"
        done || true
    stow --restow --dir="$DOTFILES_DIR" --target="$HOME" "$dir" \
      || { echo "ERROR: stow failed for '$dir'."; exit 1; }
  else
    echo "  WARN: '$dir' not found, skipping."
  fi
done

if [[ "$SKIP_PACKAGES" == true ]]; then
  echo "Skipping package installation (--skip-packages)"
else
  echo "Running package installations..."
  omarchy-sudo-passwordless-toggle
  trap 'omarchy-sudo-passwordless-toggle' EXIT
  (cd "$DOTFILES_DIR/install" && bash install.sh)
  omarchy-sudo-passwordless-toggle
  trap - EXIT
fi

echo "Done."
