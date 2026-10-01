# Books sync

Install or repair the complete setup:

```bash
bash ~/.dotfiles/install/install_books_sync.sh
```

The normal dotfiles package installer also discovers this script. On Omarchy it
installs missing dependencies, links this package into your home directory, loads
the Google OAuth client from 1Password, authorizes Drive if needed, initializes
the first merge, and enables a systemd user timer.

## 1Password and authorization

The default item is **Google Personal Desktop Client**, ID
`cbzpnxwlattw4kvp6mslnnincy`, with fields named `client_id` and `client_secret`.
Unlock 1Password and enable its CLI integration before running setup, or sign in
with `op signin`. To select a different item or specify a vault:

```bash
BOOKS_SYNC_OP_ITEM="Google Personal Desktop Client" \
BOOKS_SYNC_OP_VAULT="Personal" \
bash ~/.dotfiles/install/install_books_sync.sh
```

Secrets are fetched with `op item get` and kept out of output and process
arguments. They and the OAuth token live only in
`~/.config/rclone/rclone.conf` (mode `0600`), never in this repository.
Background sync uses that configuration and does not need 1Password unlocked.
A fresh machine requires browser authorization; the client credentials alone
cannot authorize a Google account. Use a Desktop OAuth client with Drive access
and production publishing status for durable refresh tokens.

## Behavior and repeat runs

- Local folder: `~/Documents/Books`.
- Exact Drive folder ID: `1MTAbND7hbreYNmH3wKCmZxggdtfduSsT`.
- Sync after login, then 15 minutes after each completed run while awake/online.
- On the first run, preview and merge both collections. The newer version wins
  same-path conflicts; overwritten files are backed up.
- Subsequent setup runs preserve the authorization and baseline and use normal
  incremental bisync. They never automatically resync an existing baseline.
- Both versions of ongoing conflicts are retained with numbered conflict names.
- Deletions propagate in both directions. Local backups are in
  `~/.local/share/books-sync-backups/`; Drive backups are in the excluded
  `.books-sync-backups/` folder inside Books. Backups are not automatically pruned.
- Sync state is in `~/.local/state/books-sync/`, outside the repository. Preserve
  it on the same machine; missing initialized snapshots stop setup rather than
  resurrecting deleted files. A fresh machine gets a new baseline.
- Setup rejects an existing remote with a different target. Changes to the OAuth
  client require reauthorization but preserve the sync baseline.
- Replaced standalone scripts/units are retained under the state's
  `setup-backups/`; repeated runs leave correct links in place.
- Changes to paths/filters require reviewing and explicitly rebuilding the
  baseline; setup refuses to silently change an existing identity.

## Commands

```bash
~/.local/bin/books-sync preview                   # Dry-run upcoming changes
systemctl --user start books-sync.service         # Sync now
systemctl --user list-timers books-sync.timer     # Next scheduled sync
journalctl --user -u books-sync.service -n 50     # Logs
systemctl --user disable --now books-sync.timer   # Pause
```

After revoked/expired authorization, use `~/.local/bin/books-sync-authorize`.
If existing credentials are unchanged it preserves the token; to explicitly
reauthorize the account run:

```bash
rclone config reconnect books-drive: --config ~/.config/rclone/rclone.conf
```
