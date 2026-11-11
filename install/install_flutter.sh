#!/usr/bin/env bash
# Flutter SDK managed by mise (replaces the AUR flutter-bin package, which also
# dragged in unionfs-fuse). Update with `mise upgrade flutter`.
set -euo pipefail

mise use --global flutter@latest

# Only drop the AUR packages once the mise-managed SDK is in place.
for pkg in flutter-bin unionfs-fuse; do
  if pacman -Q "$pkg" &>/dev/null; then
    sudo pacman -Rns --noconfirm "$pkg"
  fi
done

# flutter-bin created this group for its unionfs trick; mise needs nothing of
# the sort.
if getent group flutter >/dev/null; then
  sudo groupdel flutter
fi
