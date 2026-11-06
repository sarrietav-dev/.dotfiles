#!/usr/bin/env bash
# Dictation: Omarchy's Superwhisper backend.
#
# Installs and configures Superwhisper, selects it as the dictation backend in
# ~/.config/omarchy/defaults/dictation, and leaves Omarchy's stock keys in
# charge: Alt+Space toggles dictation, Right Alt is push-to-talk.
#
# --background keeps the settings window closed so this stays non-interactive.
omarchy install dictation superwhisper --background
