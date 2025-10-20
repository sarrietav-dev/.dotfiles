return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        herb_ls = {
          filetypes = { "html", "eruby", "erb" },
        },
        html = {
          filetypes = { "html", "eruby", "erb" },
        },
      },
    },
  },
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        providers = {
          snippets = {
            opts = {
              extended_filetypes = { ruby = { "rails" } },
            },
          },
        },
      },
    },
  },
}
