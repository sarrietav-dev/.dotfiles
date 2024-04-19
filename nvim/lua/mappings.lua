require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>nh", ":noh<cr>", { desc = "Clear last search highlighting" })

-- Nvim-Dap
map("n", "<F5>", require("dap").continue, { desc = "Debug: Continue" })
map("n", "<F10>", require("dap").step_over, { desc = "Debug: Step over" })
map("n", "<F11>", require("dap").step_into, { desc = "Debug: Step into" })
map("n", "<F12>", require("dap").step_out, { desc = "Debug: Step out" })
map("n", "<leader>b", require("dap").toggle_breakpoint, { desc = "Debug: Toggle breakpoint" })
map(
  "n",
  "<leader>b",
  require("dap").toggle_breakpoint(vim.fn.input "Breakpoint condition: "),
  { desc = "Debug: Set conditional breakpoint" }
)
map(
  "n",
  "<leader>lp",
  require("dap").toggle_breakpoint(nil, nil, vim.fn.input "Log point message: "),
  { desc = "Debug: Set Log point" }
)
map("n", "<leader>dl", require("dap").run_last, { desc = "Debug: Run last" })
map("n", "<leader>dr", require("dap").repl.open, { desc = "Debug: Open REPL" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--
