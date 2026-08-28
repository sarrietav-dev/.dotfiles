# Omassistant

Omassistant is a voice-controlled personal agent for
[Omarchy](https://omarchy.org/). Press a hotkey, speak, and a pixel-art desktop
companion appears in the top-right corner while your selected Omarchy agent
handles the request and Piper speaks its answer.

## Features

- Local speech-to-text through Voxtype.
- Uses the agent selected by `omarchy-default-agent`; it is not tied to one AI
  provider or CLI.
- Supports OpenCode, Claude Code, Codex, Gemini, Copilot, Crush, Grok, Oh My
  Pi, and Pi.
- Full access for desktop actions such as opening applications, setting
  reminders, or changing Omarchy settings.
- Local speech synthesis with Piper and the `en_US-ryan-medium` voice.
- Animated pixel companion with listening, transcribing, thinking, and
  speaking states.
- Live microphone waveform and cancellable requests.

## Security

Omassistant intentionally gives the selected agent the same unattended,
full-access behavior used by Omarchy's agent launcher. Spoken requests can run
commands, edit files, access configured MCP services, and change the system
without another confirmation prompt. Only install and use it if that is the
behavior you want.

Omarchy plugins run unsandboxed inside `omarchy-shell`. Review plugin code
before enabling third-party installations.

## Requirements

- A current Omarchy installation with `omarchy-shell` plugin support.
- Voxtype configured and running as a user service.
- An Omarchy default agent selected with `omarchy default agent <name>`.
- `uv`, `ffmpeg`, `jq`, and PipeWire's `pw-play`.

## Install

```bash
omarchy plugin add https://github.com/sarrietav-dev/omassistant.git --enable --yes
~/.config/omarchy/plugins/sarrietav-dev.omassistant/bin/omassistant-setup
```

The setup command creates an isolated Piper environment under
`~/.local/share/omassistant/` and downloads the US English Ryan medium voice.
That voice is licensed CC BY-NC-SA 4.0.

Add the hotkey to `~/.config/hypr/bindings.lua`:

```lua
o.bind("F10", "Voice assistant", "~/.config/omarchy/plugins/sarrietav-dev.omassistant/bin/omassistant-toggle")
```

Then validate Hyprland:

```bash
hyprctl reload
hyprctl configerrors
```

If Voxtype's own waveform appears alongside Omassistant, add this to
`~/.config/voxtype/config.toml` and restart Voxtype:

```toml
[osd]
enabled = false
```

```bash
systemctl --user restart voxtype.service
```

## Usage

- Press F10 once to start listening.
- Press F10 again to submit the request.
- Press F10 while transcribing, thinking, or speaking to cancel.

Changing the default agent takes effect on the next request:

```bash
omarchy default agent claude
omarchy default agent opencode
```

## Development

```bash
omarchy plugin validate .
```

Copy the repository to
`~/.config/omarchy/plugins/sarrietav-dev.omassistant`, rescan plugins, and
enable it:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable sarrietav-dev.omassistant
```

## License

Omassistant is released under the MIT License. Piper and downloaded voice
models retain their own licenses.
