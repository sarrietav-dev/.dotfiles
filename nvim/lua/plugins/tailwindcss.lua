return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tailwindcss = {
          emmetCompletions = true,
          filetypes_include = {
            "erb",
          },
        },
      },
    },
  },
}
