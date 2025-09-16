return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local configs = require("lspconfig.configs")
      local util = require("lspconfig.util")

      configs.herb_ls = {
        default_config = {
          cmd = { "herb-language-server", "--stdio" },
          filetypes = { "html", "ruby", "eruby" },
          root_dir = util.root_pattern("Gemfile", ".git"),
        },
      }

      opts.servers = opts.servers or {}
      opts.servers.herb_ls = opts.servers.herb_ls or {}
      opts.servers.html = opts.servers.html or {}
    end,
  },
}
