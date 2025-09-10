#!/usr/bin/env zsh
if [[ "$(hyprctl monitors)" =~ "\\sDP-[0-9]+" ]]; then
  hyprctl keyword monitor "eDP-1,disable"
fi
