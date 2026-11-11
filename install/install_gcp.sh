#!/usr/bin/env bash
# Google Cloud CLI from the official SDK tarball, installed under ~/.local/share
# so that it can update itself (`gcloud components update`). gsutil ships inside
# the SDK, so there is no separate package. Replaces google-cloud-cli{,-gsutil}
# from the AUR.
set -euo pipefail

SDK_DIR="$HOME/.local/share/google-cloud-sdk"

if [[ ! -x "$SDK_DIR/bin/gcloud" ]]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL -o "$tmp/gcloud.tar.gz" \
    https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
  mkdir -p "$HOME/.local/share"
  tar -xzf "$tmp/gcloud.tar.gz" -C "$HOME/.local/share"
  "$SDK_DIR/install.sh" --quiet --usage-reporting false --path-update false --command-completion false
fi

# The SDK's own updater; the PATH entry lives in bash/.bashrc.
"$SDK_DIR/bin/gcloud" components update --quiet

# The AUR packages install the same files under /usr; drop them now that the
# self-updating SDK is in place.
for pkg in google-cloud-cli google-cloud-cli-gsutil; do
  if pacman -Q "$pkg" &>/dev/null; then
    sudo pacman -Rns --noconfirm "$pkg"
  fi
done
