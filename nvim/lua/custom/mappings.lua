---@type MappingsTable
local M = {}

M.general = {
  n = {
    [";"] = { ":", "enter command mode", opts = { nowait = true } },
    ["<leader>gce"] = { ":Copilot enable <CR>", "Enable copilot" },
    ["<leader>gcd"] = { ":Copilot disable <CR>", "Disable copilot" },
  },
  v = {
    [">"] = { ">gv", "indent" },
  },
}

-- more keybinds!

return M
