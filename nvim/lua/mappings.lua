require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>nh", ":noh<cr>", { desc = "Clear last search highlighting" })
map({ "n", "i", "v" }, "<A-Down>", "<C-w>5-", { desc = "Resize window height" })
map({ "n", "i", "v" }, "<A-Up>", "<C-w>5+", { desc = "Resize window height" })
map({ "n", "i", "v" }, "<A-Left>", "<C-w>5<", { desc = "Resize window width" })
map({ "n", "i", "v" }, "<A-Right>", "<C-w>5>", { desc = "Resize window width" })
