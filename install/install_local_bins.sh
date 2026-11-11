#!/usr/bin/env bash
# Install the upstream release binaries that replaced AUR -bin packages
# (spotifast, omaread, sift, opentunnel, android-cli, piper-tts), then drop the
# AUR packages they replace.
set -euo pipefail

"$HOME/.local/bin/update-local-bins" --force

# The replacements link against the same libraries their AUR counterparts pulled
# in. Mark those dependencies explicit before removing, so `-Rns` here and the
# orphan sweep in `omarchy update` cannot take them away from the new binaries.
mark_deps_explicit() {
  local pkg=$1 dep
  for dep in $(pacman -Qi "$pkg" | sed -n 's/^Depends On *: //p'); do
    pacman -Q "$dep" &>/dev/null &&
      sudo pacman -D --asexplicit --noconfirm "$dep" >/dev/null
  done
}

for pkg in spotifast-bin omaread-bin sift-reader opentunnel-bin piper-tts-bin android-cli; do
  pacman -Q "$pkg" &>/dev/null || continue
  mark_deps_explicit "$pkg"
  sudo pacman -Rns --noconfirm "$pkg"
done
