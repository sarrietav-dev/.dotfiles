return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "emmet-ls",
        "html-lsp",
        -- other tools...
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        emmet_ls = {
          filetypes = {
            "html",
            "css",
            "scss",
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "eruby", -- Add eruby here
          },
          init_options = {
            html = {
              options = {
                ["bem.enabled"] = true,
              },
            },
          },
        },
      },
    },
  },
}
