#!/usr/bin/env bash
# Flutter SDK managed by mise (replaces the AUR flutter-bin package, which also
# dragged in unionfs-fuse). Update with `mise upgrade flutter`.
set -euo pipefail

mise use --global flutter@latest
