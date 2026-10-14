#!/usr/bin/env bash
# Omaread: keyboard-first EPUB reader (Rust + GTK4 / libadwaita + WebKitGTK).
# Idempotent standalone installer; also discovered by install/install.sh.
# Installs the prebuilt omaread-bin from the AUR. SUPER+SHIFT+R opens it (see
# hypr/.config/hypr/bindings.lua).
set -euo pipefail

# Drop a copy built from source by bin/omaread-install: it sits earlier on
# PATH than /usr/bin, and its desktop file shadows the package's.
APP_ID=io.github.sarrietav_dev.Omaread
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
local_copy=("$HOME/.local/bin/omaread" "$DATA/applications/$APP_ID.desktop"
  "$DATA/icons/hicolor/scalable/apps/$APP_ID.svg")
for f in "${local_copy[@]}"; do
  [[ -e "$f" ]] && rm -f "$f" && echo "omaread: removed local install $f"
done
update-desktop-database "$DATA/applications" 2>/dev/null || true

omarchy pkg aur add omaread-bin
