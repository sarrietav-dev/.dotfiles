# omarchy

Stowed config for the Omarchy shell and user customizations (`~/.config/omarchy/`).

## Tracked here

- `shell.json` - bar layout, plugins, idle settings
- `shell.toml` - font settings
- `defaults/agent` - default agent (opencode)
- `hooks/` - theme-set omazed hook, post-update hooks (voxtype, agent, fingerprint), theme-set.d `30-hunk-theme`, and the `.d` dirs (via `.gitkeep`)
- `lock-designs/Ring.qml` - customized Ring lock design
- `branding/` - custom about/screensaver ASCII art
- `plugins/sarrietav-dev.omassistant/` - custom voice assistant plugin (no upstream)
- `plugins/sebas.bible/` - git submodule
- `plugins/sebas.notifications/` - [Notification Center](https://github.com/sarrietav-dev/omarchy-notifications), git submodule; grouped toasts, theme-native history, Focus, Gmail-style snooze and custom date/time picker
- `plugins/sebas.pomodoro/` - Pomodoro widget; installed and synced across devices by `install/install_pomodoro_sync.sh` (see `pomodoro-sync/`)

Initialize plugin submodules after cloning these dotfiles:

```sh
git submodule update --init --recursive
```

Notification Center is enabled in `shell.json` in place of the stock notification
service; `Super+N` opens the center and `Super+Alt+N` toggles Focus. Restart the
shell after installing/updating it: `omarchy restart shell`.
Notification preferences and all notification/history/snooze state are generated
locally by the plugin, not checked into this repository.

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
