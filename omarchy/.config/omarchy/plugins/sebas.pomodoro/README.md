# Pomodoro

Omarchy bar widget: one task per 25-minute session, 5-minute rest, a ring
countdown with four session dots, a parking lot for distracting ideas, and an
optional work log. Everything is stored in SQLite at
`~/.local/share/omarchy-pomodoro/pomodoro.db`.

Settings (inline in `shell.json`): `focusMinutes` (25), `breakMinutes` (5),
`requireTask` (true), `askLog` (true).

Logs are shared between devices by `pomodoro-sync`; see
`~/.dotfiles/pomodoro-sync/README.md`. Without it the plugin works standalone.

Note: the shell caches plugin QML, so run `omarchy-restart-shell` after editing.
