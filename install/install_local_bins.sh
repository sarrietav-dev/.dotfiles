#!/usr/bin/env bash
# Install the upstream release binaries that replaced AUR -bin packages
# (spotifast, omaread, sift, opentunnel, android-cli, piper-tts).
set -euo pipefail

"$HOME/.local/bin/update-local-bins" --force
