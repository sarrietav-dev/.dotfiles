return {
  adapters = {
    ["neotest-go"] = {
      -- Here we can set options for neotest-go, e.g.
      -- args = { "-tags=integration" }
      recursive_run = true,
    },
  },
  status = { virtual_text = true },
  output = { open_on_run = true },
  quickfix = {
    open = function()
      vim.cmd "copen"
    end,
  },
}
