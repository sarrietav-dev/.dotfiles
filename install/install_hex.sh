#!/usr/bin/env bash
# Hex: local voice dictation (hold a key, speak, it types).
# Linux build is still beta; upstream README recommends the AUR package.
omarchy pkg aur add hex-bin

# Hex talks to a running daemon; the package ships the user unit.
systemctl --user enable --now hex.service
