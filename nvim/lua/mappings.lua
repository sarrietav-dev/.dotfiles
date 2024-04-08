require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>nh", ":noh<cr>", { desc = "Clear last search highlighting" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
