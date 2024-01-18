local on_attach = require("plugins.configs.lspconfig").on_attach
local capabilities = require("plugins.configs.lspconfig").capabilities

local lspconfig = require "lspconfig"

-- if you just want default config for the servers then put them in a table
local servers = {
  "html",
  "cssls",
  "tsserver",
  "clangd",
  "tailwindcss",
  "eslint",
  "gopls",
  "rust_analyzer",
  "graphql",
  "dockerls",
  "astro",
  "angularls",
  "bashls",
  "docker_compose_language_service",
  "svelte",
}

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
  }
end

lspconfig["rust_analyzer"].setup {
  on_attach = on_attach,
  capabilities = capabilities,
  root_dir = lspconfig.util.root_pattern "Cargo.toml",
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = {
        command = "clippy",
      },
      cargo = {
        allFeatures = true,
      },
    },
  },
}

--
-- lspconfig.pyright.setup { blabla}
