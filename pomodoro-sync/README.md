# Pomodoro sync

Shares the Pomodoro widget's work log between devices through Google Drive.

```bash
bash ~/.dotfiles/install/install_pomodoro_sync.sh
```

The installer is idempotent and also discovered by `install/install.sh`. It links
this package and the `sebas.pomodoro` plugin into your home directory, enables the
plugin, and starts a systemd user timer.

## How it works

Every device owns one file, so nothing can conflict:

1. Snapshot the local DB (`~/.local/share/omarchy-pomodoro/pomodoro.db`) without
   the running timer, and upload it as `<hostname>.db` when it changed.
2. Download the other devices' snapshots to `~/.local/share/omarchy-pomodoro/peers/`.
3. Import their finished sessions into the local `sessions_remote` table, which the
   widget merges into today's list, the session count, and recent-task chips.

The timer runs 3 minutes after login, then 15 minutes after each run. The widget
also starts a sync right after a session is saved. The running timer is never
shared; each device has its own.

## Drive access

It reuses the `books-drive` rclone remote (and token) from `books-sync`, re-rooted
to a folder named `omarchy-pomodoro` in My Drive via an rclone connection string, so
no extra authorization is needed and the Books config and baseline are untouched.
If the installer finds no `books-drive` remote it runs the Books installer first.

When Google rejects the token (`invalid_grant`), Books and Pomodoro sync both stop
until you reauthorize:

```bash
rclone config reconnect books-drive: --config ~/.config/rclone/rclone.conf
```

## Commands

```bash
systemctl --user start pomodoro-sync.service     # Sync now
systemctl --user list-timers pomodoro-sync.timer # Next scheduled sync
journalctl --user -u pomodoro-sync.service -n 50 # Logs
systemctl --user disable --now pomodoro-sync.timer
bash ~/.dotfiles/pomodoro-sync/tests/test_sync.sh # Two-device test, no Drive needed
```

Override with `POMODORO_DEVICE` (device name, default `hostname -s`) and
`POMODORO_SYNC_REMOTE` (any rclone path).
