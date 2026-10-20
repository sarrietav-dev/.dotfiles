#!/usr/bin/env bash

# flea: keyboard-first file manager (omarchy repo), set as the default file manager.
pacman -Qi flea &>/dev/null || sudo pacman -S --noconfirm --needed flea

# Idempotent: sets inode/directory mime default and the managed block in hypr/bindings.lua.
flea --default

# UI state is real, writable state (flea refuses to write through a symlink; it is
# deliberately not stowed), so seed the personal defaults once, on first install only.
if [[ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/flea/ui.json" ]]; then
  # Sort every folder alphabetically by name, folders first.
  flea --ui-state '{"sort":{"key":"name","reverse":false},"foldersFirst":true}' >/dev/null || true
fi
