#!/usr/bin/env bash
# Speech Dispatcher + Piper TTS for Foliate / text-to-speech.
# Phase 1 (user-level, warm server + streaming): sentence chunk tuning,
# streaming playback, and a persistent wyoming-piper server so Piper's
# model stays loaded (no per-chunk reload gap).
# This script is idempotent: safe to re-run any time.
set -euo pipefail

# --- Packages ---------------------------------------------------------------
omarchy pkg add speech-dispatcher
omarchy pkg aur add piper-tts-bin

# --- Voice models -----------------------------------------------------------
VOICE_ROOT=/usr/share/piper-voices/en/en_US
declare -A VOICES=(
  [lessac/high/en_US-lessac-high]=lessac/high
  [lessac/medium/en_US-lessac-medium]=lessac/medium
  [ryan/high/en_US-ryan-high]=ryan/high
  [amy/medium/en_US-amy-medium]=amy/medium
  [amy/low/en_US-amy-low]=amy/low
  [kristin/medium/en_US-kristin-medium]=kristin/medium
  [libritts_r/medium/en_US-libritts_r-medium]=libritts_r/medium
  [hfc_male/medium/en_US-hfc_male-medium]=hfc_male/medium
)

BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US"

sudo mkdir -p "$VOICE_ROOT"
for rel in "${!VOICES[@]}"; do
  model="$VOICE_ROOT/$rel.onnx"
  if [[ ! -f "$model" ]]; then
    echo "Downloading voice: $rel"
    tmp_model=$(mktemp)
    tmp_json=$(mktemp)
    curl -sL -o "$tmp_model" "$BASE/$rel.onnx"
    curl -sL -o "$tmp_json" "$BASE/$rel.onnx.json"
    sudo install -Dm644 "$tmp_model" "$model"
    sudo install -Dm644 "$tmp_json" "$model.json"
    rm -f "$tmp_model" "$tmp_json"
  fi
done

# --- Speech Dispatcher config ------------------------------------------------
MODULE_DIR=/etc/speech-dispatcher/modules
SPEECHD_CONF=/etc/speech-dispatcher/speechd.conf

sudo mkdir -p "$MODULE_DIR"

sudo tee "$MODULE_DIR/piper.conf" >/dev/null <<'PIPERCONF'
# piper output module for Speech Dispatcher via the generic plugin.
# Uses the piper command line client for synthesis.
# See https://github.com/rhasspy/piper for more information.

Debug 0

GenericExecuteSynth \
"printf %s \'$DATA\' | piper-tts -q --model $VOICE -f - 2>/dev/null | paplay"

GenericCmdDependency "piper-tts"
GenericCmdDependency "paplay"
GenericSoundIconFolder "/usr/share/sounds/sound-icons/"

GenericDefaultCharset "utf-8"

AddVoice	"en"	"MALE1"		"/usr/share/piper-voices/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
AddVoice	"en"	"MALE2"		"/usr/share/piper-voices/en/en_US/ryan/high/en_US-ryan-high.onnx"
AddVoice	"en"	"MALE3"		"/usr/share/piper-voices/en/en_US/hfc_male/medium/en_US-hfc_male-medium.onnx"
AddVoice	"en"	"FEMALE1"	"/usr/share/piper-voices/en/en_US/amy/medium/en_US-amy-medium.onnx"
AddVoice	"en"	"FEMALE2"	"/usr/share/piper-voices/en/en_US/amy/low/en_US-amy-low.onnx"
AddVoice	"en"	"FEMALE3"	"/usr/share/piper-voices/en/en_US/libritts_r/medium/en_US-libritts_r-medium.onnx"
AddVoice	"en"	"CHILD_MALE"	"/usr/share/piper-voices/en/en_US/kristin/medium/en_US-kristin-medium.onnx"

DefaultVoice	"/usr/share/piper-voices/en/en_US/lessac/medium/en_US-lessac-medium.onnx"

GenericRateForceInteger 0
GenericRateMultiply 0
GenericRateAdd 0
GenericPitchMultiply 0
GenericPitchAdd 0
PIPERCONF

# Enable piper as the only/default module, plus required audio/voice defaults.
sudo sed -i \
  -e 's|^# AudioOutputMethod "pipewire"|AudioOutputMethod "pulse"|' \
  -e 's|^#AudioOutputMethod|AudioOutputMethod "pulse"|' \
  -e 's|^# DefaultVoiceType  "MALE1"|DefaultVoiceType  "MALE1"|' \
  "$SPEECHD_CONF"

# AddModule piper (idempotent) and set as DefaultModule.
if ! grep -q '^AddModule "piper"' "$SPEECHD_CONF"; then
  sudo sed -i 's|^#AddModule "voxin".*|AddModule "piper" "sd_generic" "piper.conf"|' "$SPEECHD_CONF"
fi
if ! grep -q '^DefaultModule piper' "$SPEECHD_CONF"; then
  sudo sed -i 's|^# DefaultModule espeak-ng|DefaultModule piper|' "$SPEECHD_CONF"
fi

# --- Enable socket activation (needed by Flatpak apps like Foliate) ----------
systemctl --user enable --now speech-dispatcher.socket

# --- Phase 1: warm Wyoming server + streaming (user-level) --------------------
# Everything below is user-scoped (~/.config, ~/.local) and idempotent:
# re-running overwrites generated files, skips satisfied installs, and
# only downloads voices that are missing locally.

# --- Phase 1 dependencies ----------------------------------------------------
omarchy pkg add jq python libpulse

BIN_DIR="$HOME/.local/bin"
VENV="$HOME/.local/share/wyoming-piper"
VOICE_DIR="$VENV/voices"
WYOMING_VOICES=(
  en_US-lessac-medium
  en_US-ryan-high
  en_US-amy-medium
  en_US-amy-low
  en_US-lessac-high
  en_US-kristin-medium
)

mkdir -p "$BIN_DIR"

# --- Stowed configs (dotfiles/tts package) ------------------------------------
# piper-stream, wyoming-say, the systemd unit and the speech-dispatcher
# override live in the tts/ stow package. Ensure it is linked (install.sh
# normally does this before running install scripts).
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TTS_FILES=(
  "$HOME/.local/bin/piper-stream"
  "$HOME/.local/bin/wyoming-say"
  "$HOME/.config/systemd/user/wyoming-piper.service"
  "$HOME/.config/speech-dispatcher/modules/piper.conf"
)
if command -v stow >/dev/null; then
  for target in "${TTS_FILES[@]}"; do
    if [[ -e "$target" && ! -L "$target" ]]; then
      echo "Removing unmanaged file to let stow link it: $target"
      rm -rf "$target"
    fi
  done
  (cd "$DOTFILES_DIR" && stow --restow --target="$HOME" tts)
else
  for target in "${TTS_FILES[@]}"; do
    if [[ ! -e "$target" ]]; then
      echo "ERROR: $target missing and stow unavailable." >&2
      echo "Install stow and run: (cd $DOTFILES_DIR && stow --target=\$HOME tts)" >&2
      exit 1
    fi
  done
fi
chmod +x "$BIN_DIR/piper-stream" "$BIN_DIR/wyoming-say"


# --- Wyoming venv (re-running venv + pip install on an existing venv is safe)
mkdir -p "$(dirname "$VENV")"
/usr/bin/python3 -m venv "$VENV"
"$VENV/bin/pip" install wyoming-piper wyoming

# --- Pre-download voices (only ones missing locally) -------------------------
mkdir -p "$VOICE_DIR"

server_up() {
  (ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null) | grep -q ':10200'
}

TEMP_SERVER_PID=""
if ! server_up; then
  echo "Starting temporary Wyoming server to fetch voices..."
  "$VENV/bin/wyoming-piper" \
    --voice en_US-lessac-medium \
    --data-dir "$VOICE_DIR" --download-dir "$VOICE_DIR" \
    --uri tcp://127.0.0.1:10200 --sentence-silence 0.2 \
    >/tmp/wyoming-install.log 2>&1 &
  TEMP_SERVER_PID=$!
  for _ in $(seq 1 40); do
    sleep 3
    if grep -q "Ready" /tmp/wyoming-install.log 2>/dev/null; then
      break
    fi
    if ! kill -0 "$TEMP_SERVER_PID" 2>/dev/null; then
      echo "WARN: temporary Wyoming server died; voice downloads may fail."
      TEMP_SERVER_PID=""
      break
    fi
  done
fi

for voice in "${WYOMING_VOICES[@]}"; do
  if [[ ! -f "$VOICE_DIR/$voice.onnx" ]]; then
    echo "Downloading voice: $voice"
    if ! echo "Warming up the voice $voice for offline use." \
        | timeout 180 "$BIN_DIR/wyoming-say" "$voice.onnx"; then
      echo "WARN: could not fetch voice $voice (offline?). Continuing."
    fi
  fi
done

if [[ -n "$TEMP_SERVER_PID" ]]; then
  kill "$TEMP_SERVER_PID" 2>/dev/null || true
fi

systemctl --user daemon-reload
# Unit file itself comes from the tts/ stow package (ensured above).
systemctl --user enable --now wyoming-piper.service


# --- Apply: restart a running dispatcher so it picks up the new module config
# Anchored pattern matches only the dispatcher binary, never this shell.
if pgrep -f '^/usr/bin/speech-dispatcher( |$)' >/dev/null; then
  pkill -f '^/usr/bin/speech-dispatcher( |$)' || true
  sleep 2
fi

echo "TTS setup complete (Phase 1: warm Wyoming server + streaming)."
