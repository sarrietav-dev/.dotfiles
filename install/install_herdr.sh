#!/usr/bin/env bash
# herdr from the omarchy repo (replaces herdr-bin from the AUR).
set -euo pipefail

# The AUR package owns /usr/bin/herdr, so pacman refuses to install the omarchy
# build over it. Remove it first; this is a no-op on a machine without it.
if pacman -Q herdr-bin &>/dev/null; then
  sudo pacman -Rns --noconfirm herdr-bin
fi

omarchy pkg add herdr
