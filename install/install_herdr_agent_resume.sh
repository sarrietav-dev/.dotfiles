#!/usr/bin/env bash

# Agent resume for herdr-app: after a reboot or a herdr-core restart, each
# restored shell starts its agent again (claude --resume <id>, codex resume,
# and so on). Fork of thuanlm215/herdr-agent-resume that adds no key binding
# and keeps stowed dotfiles as symlinks.
#
# https://github.com/sarrietav-dev/herdr-agent-resume

set -euo pipefail

REPO_URL="git@github.com:sarrietav-dev/herdr-agent-resume.git"
REPO_DIR="$HOME/Projects/herdr-agent-resume"
MOD_DIR="$HOME/.config/herdr-app/mods/agent-resume"

if ! command -v herdr-app >/dev/null 2>&1; then
  echo "herdr-app is not installed, skipping agent-resume."
  exit 0
fi

if [[ -d "$REPO_DIR/.git" ]]; then
  git -C "$REPO_DIR" pull --ff-only --quiet \
    || echo "warning: could not update $REPO_DIR, installing the local copy"
else
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone --quiet "$REPO_URL" "$REPO_DIR"
fi

if [[ -d "$MOD_DIR" ]]; then
  python3 "$REPO_DIR/scripts/install.py" --update --auto
else
  python3 "$REPO_DIR/scripts/install.py" --auto
fi
