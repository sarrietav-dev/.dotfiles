#!/usr/bin/env bash

# Install IoskeleyMono Nerd Font from GitHub releases
echo "Installing IoskeleyMono Nerd Font..."

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Download and extract IoskeleyMono NerdFont variant
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "  Downloading IoskeleyMono NerdFont..."
curl -sL https://github.com/ahatem/IoskeleyMono/releases/latest/download/IoskeleyMono-NerdFont.zip \
  -o "$TMP_DIR/ioskeley.zip"

echo "  Extracting fonts..."
unzip -q "$TMP_DIR/ioskeley.zip" -d "$TMP_DIR"

echo "  Installing fonts..."
cp "$TMP_DIR/IoskeleyMono-NerdFont/Normal"/*.ttf "$FONT_DIR/"
cp "$TMP_DIR/IoskeleyMono-NerdFont/SemiCondensed"/*.ttf "$FONT_DIR/"

echo "  Refreshing font cache..."
fc-cache -fv "$FONT_DIR" > /dev/null 2>&1

echo "  Setting as system font..."
omarchy font set "IoskeleyMono Nerd Font Mono"

echo "Done. IoskeleyMono Nerd Font installed and set as system font."
