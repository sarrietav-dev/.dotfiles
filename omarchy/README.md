# omarchy

Stowed config for the Omarchy shell and user customizations (`~/.config/omarchy/`).

## Tracked here

- `shell.json` - bar layout, plugins, idle settings
- `shell.toml` - font settings
- `defaults/agent` - default agent (opencode)
- `defaults/dictation` - dictation backend (superwhisper)
- `hooks/` - theme-set omazed hook, post-update hooks (agent, fingerprint), theme-set.d `30-hunk-theme`, and the `.d` dirs (via `.gitkeep`)
- `lock-designs/Ring.qml` - customized Ring lock design
- `branding/` - custom about/screensaver ASCII art
- `plugins/sebas.bible/` - git submodule
- `plugins/sebas.pomodoro/` - Pomodoro widget; installed and synced across devices by `install/install_pomodoro_sync.sh` (see `pomodoro-sync/`)

Optional, not stowed by default: `optional/omassistant/` is a voice assistant
plugin. Enable it with `install/optional/install_omassistant.sh`.

Initialize plugin submodules after cloning these dotfiles:

```sh
git submodule update --init --recursive
```

Notifications use Omarchy's stock `omarchy.notifications` service: grouped
toasts, Do Not Disturb and history. `Super+N` opens notification history and
`Super+Alt+N` toggles Focus; Omarchy's own `Super+comma` family also applies.
Notification state lives in `~/.local/state/omarchy/notifications/` and is not
checked into this repository.

## Not tracked (recreate after a fresh install)

These are third-party plugin clones and can be restored with:

```sh
omarchy plugin clone io.github.sirjul1337.lock-explorer
omarchy plugin clone io.github.tallsam.navbar-cat
omarchy plugin clone slcode777.omagotchi
```

`lock-explorer` is also listed in `shell.json` under `cloneSourceRestores`, so
the shell re-clones it automatically; the other two still need the manual
commands above.
