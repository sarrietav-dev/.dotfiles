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
    stow --restow --dir="$DOTFILES_DIR" --target="$HOME" "$dir" \
      || { echo "ERROR: stow failed for '$dir'. A conflicting file may exist at the target. Resolve it manually."; exit 1; }
  else
    echo "  WARN: '$dir' not found, skipping."
  fi
done

if [[ "$SKIP_PACKAGES" == true ]]; then
  echo "Skipping package installation (--skip-packages)"
else
  echo "Running package installations..."
  (cd "$DOTFILES_DIR/install" && bash install.sh)
fi

echo "Done."
