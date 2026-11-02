-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- JetBrains products: floating dialog/tab-dragging fixes.
o.window({ class = "^jetbrains-.*$", float = true, title = "^$|^\\s$|^win\\d+$" }, { no_initial_focus = true })
o.window({ class = "^jetbrains-.+$", float = true }, { tag = "+jb" })
o.window({ tag = "jb" }, { stay_focused = true })
o.window({ tag = "jb" }, { no_initial_focus = true })
o.window({ class = "^jetbrains-(?!toolbox)" }, { focus_on_activate = true })

-- Center JetBrains popups except the context menu.
o.window({ class = "^jetbrains-(?!toolbox)", title = "^(?!win.*)", float = true }, { move = "30% 30%", size = "40% 40%" })

-- Tab dragging (single space title).
o.window({ class = "^(.*jetbrains.*)$", title = "^\\s$" }, { no_initial_focus = true })
o.window({ class = "^(.*jetbrains.*)$", title = "^\\s$" }, { no_focus = true })

-- Float the Google Tasks webapp.
o.window("brave-tasks.google.com__mobile_list_~default-Default", { float = true, center = true, size = "480 700" })

-- 1Password 8.12+ uses com.onepassword.OnePassword, which Omarchy's default
-- ^(1password|1Password)$ rule misses. Float all variants (main, Quick Access, prompts).
o.window("^(1[pP]assword|com.onepassword.OnePassword|com.1password.1Password)$", { no_screen_share = true, tag = "+floating-window" })

-- Playwright CLI (agent browser automation): never steal focus / switch workspace.
-- Playwright calls Page.bringToFront() on actions and opens new windows for tabs;
-- Omarchy's defaults set misc:focus_on_activate = true, so Hyprland obeys those
-- activation requests and yanks you to the browser's workspace.
-- suppress_event activatefocus = ignore activation requests for this window only.
-- no_initial_focus = don't grab focus when the browser window first opens.
o.window({ class = "^playwright-cli$" }, { suppress_event = "activatefocus", no_initial_focus = true })

-- oma-cast launcher bindings
pcall(require, "hypr.oma-cast")
