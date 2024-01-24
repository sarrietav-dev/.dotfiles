local M = {}
M.treesitter = {
  ensure_installed = {
    "vim",
    "lua",
    "html",
    "css",
    "scss",
    "javascript",
    "typescript",
    "tsx",
    "go",
    "gomod",
    "rust",
    "markdown",
    "markdown_inline",
    "graphql",
    "svelte",
    "dockerfile",
    "astro"
  },
  indent = {
    enable = true,
    -- disable = {
    --   "python"
    -- },
  },
}

M.mason = {
  ensure_installed = {
    -- lua stuff
    "lua-language-server",
    "stylua",

    -- web dev stuff
    "css-lsp",
    "html-lsp",
    "typescript-language-server",
    "prettierd",
    "tailwindcss-language-server",
    "eslint-lsp",

    -- go stuff
    "gopls",

    -- rust stuff
    "rust-analyzer",
    "graphql-language-service-cli"
  },
}

-- git support in nvimtree
M.nvimtree = {
  git = {
    enable = true,
  },

  renderer = {
    highlight_git = true,
    icons = {
      show = {
        git = true,
      },
    },
  },
}

M.copilot = {
  suggestion = {
    enable = true,
    auto_trigger = true,
    debounce = 75,
    keymap = {
      accept = "<M-l>",
      accept_word = false,
      accept_line = false,
    },
  },
  panel = {
    enable = false,
  }
}

M.colorizer = {
  user_default_options = {
    tailwind = true,
  }
}

return M
