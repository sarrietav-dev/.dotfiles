#!/bin/bash
# Security bits Omarchy's defaults don't cover:
#   - omarchy-panic, the remote lock/wipe script invoked over SSH
#   - SSH and LocalSend scoped to tailscale0 and the LAN instead of the world
#   - keyring unlock at SDDM login (pam_gnome_keyring in the auth stack)
#   - the gitleaks pre-commit hook for this repo
# Safe to re-run: every step is idempotent.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "  security: omarchy-panic"
sudo install -m 0755 -o root -g root \
  "$REPO/scripts/.local/bin/omarchy-panic" /usr/local/bin/omarchy-panic

echo "  security: firewall"
sudo ufw --force enable >/dev/null
sudo ufw --force delete limit 22/tcp >/dev/null 2>&1 || true
sudo ufw limit in on tailscale0 to any port 22 proto tcp comment 'ssh tailscale' >/dev/null
sudo ufw limit from 192.168.0.0/16 to any port 22 proto tcp comment 'ssh lan' >/dev/null
sudo ufw limit from 10.0.0.0/8 to any port 22 proto tcp comment 'ssh lan' >/dev/null
for proto in udp tcp; do
  sudo ufw allow in on tailscale0 to any port 53317 proto "$proto" comment 'localsend tailscale' >/dev/null
  sudo ufw allow from 192.168.0.0/16 to any port 53317 proto "$proto" comment 'localsend lan' >/dev/null
done

echo "  security: keyring unlock at login"
PAM=/etc/pam.d/sddm
if ! grep -qE '^auth[[:space:]]+optional[[:space:]]+pam_gnome_keyring.so' "$PAM"; then
  sudo cp -a "$PAM" "$PAM.bak.$(date +%s)"
  sudo sed -i '/^auth[[:space:]]\{1,\}include[[:space:]]\{1,\}system-login$/a auth        optional    pam_gnome_keyring.so' "$PAM"
fi
if ! grep -qE '^password[[:space:]]+optional[[:space:]]+pam_gnome_keyring.so' "$PAM"; then
  sudo sed -i '/^password[[:space:]]\{1,\}include[[:space:]]\{1,\}system-login$/a password    optional    pam_gnome_keyring.so' "$PAM"
fi

echo "  security: gitleaks pre-commit hook"
git -C "$REPO" config core.hooksPath .githooks
