#!/usr/bin/env bash
set -euo pipefail

yay -S --noconfirm vicinae-bin

# omarchy-menu Vicinae extension: native port of the Omarchy bash menu.
# See https://github.com/sarrietav-dev/omarchy-menu
#
# `vici build` defaults its --out to the Vicinae extensions directory, so this
# builds from a separate source checkout rather than in the extensions dir
# itself -- building in place makes vici try to copy package.json onto itself
# and it errors out (src and dest cannot be the same).
SRC_DIR="$HOME/Projects/vicinae-omarchy-menu"
if [[ -d "$SRC_DIR/.git" ]]; then
  git -C "$SRC_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$SRC_DIR")"
  git clone git@github.com:sarrietav-dev/omarchy-menu.git "$SRC_DIR"
fi
(cd "$SRC_DIR" && npm install && npm run build)

systemctl --user daemon-reload
systemctl --user enable --now vicinae-theme-sync.path
