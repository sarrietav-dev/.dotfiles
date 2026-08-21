#!/usr/bin/env bash
# Speech Dispatcher + Piper TTS for Foliate / text-to-speech.
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

mkdir -p "$VOICE_ROOT"
for rel in "${!VOICES[@]}"; do
  model="$VOICE_ROOT/$rel.onnx"
  if [[ ! -f "$model" ]]; then
    mkdir -p "$(dirname "$model")"
    echo "Downloading voice: $rel"
    curl -sL -o "$model" "$BASE/$rel.onnx"
    curl -sL -o "$model.json" "$BASE/$rel.onnx.json"
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

AddVoice	"en"	"MALE1"		"/usr/share/piper-voices/en/en_US/lessac/high/en_US-lessac-high.onnx"
AddVoice	"en"	"MALE2"		"/usr/share/piper-voices/en/en_US/ryan/high/en_US-ryan-high.onnx"
AddVoice	"en"	"MALE3"		"/usr/share/piper-voices/en/en_US/hfc_male/medium/en_US-hfc_male-medium.onnx"
AddVoice	"en"	"FEMALE1"	"/usr/share/piper-voices/en/en_US/amy/medium/en_US-amy-medium.onnx"
AddVoice	"en"	"FEMALE2"	"/usr/share/piper-voices/en/en_US/amy/low/en_US-amy-low.onnx"
AddVoice	"en"	"FEMALE3"	"/usr/share/piper-voices/en/en_US/libritts_r/medium/en_US-libritts_r-medium.onnx"
AddVoice	"en"	"CHILD_MALE"	"/usr/share/piper-voices/en/en_US/kristin/medium/en_US-kristin-medium.onnx"

DefaultVoice	"/usr/share/piper-voices/en/en_US/lessac/high/en_US-lessac-high.onnx"

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

echo "TTS setup complete."
