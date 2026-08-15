-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Personal overrides from the old bindings.conf.
-- The Omarchy defaults already cover Terminal, Browser, File manager, Tmux,
-- Editor, Music, Music TUI, Docker, Obsidian, Passwords, ChatGPT, Email,
-- YouTube, Google Messages, X, and X Post.

-- Replace default bindings that we don't want (Omawrite, Agent, Hey Calendar).
hl.unbind("SUPER + SHIFT + C")
hl.unbind("SUPER + SHIFT + ALT + A")

-- Extra application bindings.
o.bind("SUPER + SHIFT + CTRL + B", "Browser (Work)", "uwsm-app -- google-chrome-stable --new-window")
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })
o.bind("SUPER + SHIFT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind("SUPER + SHIFT + CTRL + SLASH", "Passwords (quick access)", "uwsm-app -- 1password --quick-access")
o.bind("SUPER + SHIFT + ALT + A", "Gemini", { webapp = "https://gemini.google.com" })
o.bind("SUPER + SHIFT + CTRL + T", "Google Tasks",
  { webapp = "https://tasks.google.com/mobile/list/~default", focus = true })
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.google.com" })

hl.unbind("PRINT")
hl.unbind("F12")
hl.unbind("ALT + SHIFT + 4")

o.bind("PRINT", "Screenshot", "omasnap")
o.bind("F12", "Screenshot", "omasnap")
o.bind("ALT + SHIFT + 4", "Screenshot", "omasnap")

hl.layer_rule({
  match = { namespace = "^omasnap$" },
  no_anim = true,
  animation = "none",
})
