#!/usr/bin/env bash
# Omaread: keyboard-first EPUB reader (Rust + GTK4 / libadwaita + WebKitGTK).
# Idempotent standalone installer; also discovered by install/install.sh.
set -euo pipefail

SRC="${OMAREAD_SRC:-$HOME/Work/omaread}"
REPO="${OMAREAD_REPO:-git@github.com:sarrietav-dev/omaread.git}"

# GTK4, libadwaita and WebKitGTK to link against, plus a Rust toolchain.
omarchy pkg add gtk4 libadwaita webkitgtk-6.0
command -v cargo >/dev/null || omarchy install dev-env rust

# Source checkout: clone once, fast-forward on later runs. A dirty or offline
# checkout is kept rather than failing the install.
if [[ -d "$SRC/.git" ]]; then
  git -C "$SRC" pull --ff-only || echo "omaread: keeping the existing checkout (pull failed)"
elif [[ -e "$SRC" ]]; then
  echo "omaread: $SRC exists but is not a git checkout; building it as-is"
else
  mkdir -p "$(dirname "$SRC")"
  git clone "$REPO" "$SRC"
fi

# Build the release binary, then install it to ~/.local with its desktop file
# and icon. SUPER+SHIFT+R opens it (see hypr/.config/hypr/bindings.lua).
"$SRC/bin/omaread-install"
