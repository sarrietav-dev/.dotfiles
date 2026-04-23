#!/usr/bin/env bun
import { $ } from "bun";

const HOME = process.env.HOME!;
const WAYBAR_CONFIG = `${HOME}/.config/waybar/config.jsonc`;
const WAYBAR_STYLE = `${HOME}/.config/waybar/style.css`;

// --- Install waycal (AUR) ---
const waycalInstalled = (await $`which waycal`.quiet().nothrow()).exitCode === 0;
if (!waycalInstalled) {
  await $`omarchy-pkg-aur-add waycal`;
}

// --- Patch waybar config ---
const config = await Bun.file(WAYBAR_CONFIG).json();

const center: string[] = config["modules-center"];
if (!center.includes("custom/waycal")) {
  const clockIdx = center.indexOf("clock");
  center.splice(clockIdx, 0, "custom/waycal");
}

if (!config["custom/waycal"]) {
  config["custom/waycal"] = {
    format: "📅",
    "on-click": "pkill -x waycal || waycal",
    "tooltip-format": "Calendar",
  };
}

await Bun.write(WAYBAR_CONFIG, JSON.stringify(config, null, 2));

// --- Patch waybar style ---
let style = await Bun.file(WAYBAR_STYLE).text();

if (!style.includes("#custom-waycal")) {
  style += `
#custom-waycal {
  min-width: 12px;
  margin: 0 7.5px;
  font-size: 12px;
}
`;
  await Bun.write(WAYBAR_STYLE, style);
}

// --- Restart Waybar ---
await $`omarchy-restart-waybar`;
