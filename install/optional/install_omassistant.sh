#!/usr/bin/env bash
# Optional add-on: Omassistant voice assistant plugin.
#
# Not run by install.sh. Opt in explicitly with:
#   install/optional/install_omassistant.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$DOTFILES_DIR/optional/omassistant"
DST="$HOME/.config/omarchy/plugins/sarrietav-dev.omassistant"

[[ -d $SRC ]] || { echo "Missing $SRC" >&2; exit 1; }

mkdir -p "$(dirname "$DST")"
ln -sfn "$SRC" "$DST"

"$SRC/bin/omassistant-setup"

cat <<EOF

Omassistant plugin linked: $DST

Enable it in ~/.config/omarchy/shell.json by adding this to "plugins":
  { "id": "sarrietav-dev.omassistant" }

Then add the binding to ~/.config/hypr/bindings.lua:
  o.bind("F10", "Voice assistant",
    "~/.config/omarchy/plugins/sarrietav-dev.omassistant/bin/omassistant-toggle")

Finally:
  hyprctl reload && omarchy-restart-shell
EOF
