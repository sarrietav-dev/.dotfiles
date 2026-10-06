#!/usr/bin/env bash

# flea: keyboard-first file manager (omarchy repo), set as the default file manager.
pacman -Qi flea &>/dev/null || sudo pacman -S --noconfirm --needed flea

# Idempotent: sets inode/directory mime default and the managed block in hypr/bindings.lua.
flea --default
