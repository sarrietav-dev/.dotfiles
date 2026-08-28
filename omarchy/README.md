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