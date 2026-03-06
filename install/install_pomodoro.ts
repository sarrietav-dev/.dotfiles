#!/usr/bin/env bun
import { $ } from "bun";
import { existsSync } from "fs";

const HOME = process.env.HOME!;
const WAYBAR_CONFIG = `${HOME}/.config/waybar/config.jsonc`;
const WAYBAR_STYLE = `${HOME}/.config/waybar/style.css`;

// --- Install binary ---
if (!existsSync(`${HOME}/.local/bin/pomodoro`)) {
  await $`git clone https://github.com/sarrietav-dev/waybar-pomodoro-cli.git /tmp/pomo`;
  await $`mkdir -p ${HOME}/.local/bin`;
  await $`cp /tmp/pomo/pomodoro ${HOME}/.local/bin/pomodoro`;
  await $`chmod +x ${HOME}/.local/bin/pomodoro`;
  await $`rm -rf /tmp/pomo`;
}

// --- Patch waybar config ---
let config = await Bun.file(WAYBAR_CONFIG).text();

if (!config.includes('"custom/pomodoro"')) {
  config = config.replace('"network",', '"network",\n    "custom/pomodoro",');
}

if (!config.includes('"custom/pomodoro":')) {
  const module = [
    '  "custom/pomodoro": {',
    '    "exec": "pomodoro waybar",',
    '    "return-type": "json",',
    '    "interval": 1,',
    '    "signal": 11,',
    '    "on-click": "pomodoro toggle",',
    '    "on-click-middle": "pomodoro skip",',
    '    "on-click-right": "pomodoro stop"',
    "  }",
  ].join("\n");

  const lastBrace = config.lastIndexOf("}");
  const before = config.slice(0, lastBrace).trimEnd();
  const after = config.slice(lastBrace);
  config = `${before.endsWith(",") ? before : before + ","}\n${module}\n${after}`;
}

await Bun.write(WAYBAR_CONFIG, config);

// --- Patch waybar style ---
let style = await Bun.file(WAYBAR_STYLE).text();

if (!style.includes("#custom-pomodoro")) {
  style += `
#custom-pomodoro {
  min-width: 12px;
  margin: 0 7.5px;
}

#custom-pomodoro.active {
  color: #7aa364;
}

#custom-pomodoro.paused {
  color: #c18f3f;
}
`;
  await Bun.write(WAYBAR_STYLE, style);
}

// --- Restart Waybar ---
await $`omarchy-restart-waybar`;
