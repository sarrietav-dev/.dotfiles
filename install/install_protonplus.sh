#!/usr/bin/env bash
# ProtonPlus (Proton-GE / Wine-GE manager) from Flathub, so updates arrive with
# `flatpak update`. Replaces the protonplus and protonup-qt-bin AUR packages.
set -euo pipefail

flatpak install -y flathub com.vysp3r.ProtonPlus

# Both AUR managers do the same job as ProtonPlus, so they just get in the way.
for pkg in protonplus protonup-qt-bin; do
  if pacman -Q "$pkg" &>/dev/null; then
    sudo pacman -Rns --noconfirm "$pkg"
  fi
done
