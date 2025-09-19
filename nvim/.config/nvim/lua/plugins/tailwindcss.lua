return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      tailwindcss = {
        -- exclude a filetype from the default_config
        filetypes_exclude = { "markdown" },
        -- add additional filetypes to the default_config
        filetypes_include = { "eruby" },
        -- to fully override the default_config, change the below
        -- filetypes = {}
        settings = {
          tailwindCSS = {
            experimental = {
              classRegex = {
                -- default regexes
                'class\\s*=\\s*"([^"]*)"',
                'className\\s*=\\s*"([^"]*)"',
                -- custom regexes
                "tw`([^`]*)`", -- tw`...`
                'tw="([^"]*)"', -- tw="..."
                "tw={'([^']*)'}", -- tw={'...'}
                "tw\\.\\w+`([^`]*)`", -- tw.xxx`...`
                "styled\\(\\w+\\)`([^`]*)`", -- styled(...)`...`
                "styled\\.\\w+`([^`]*)`", -- styled.xxx`...`
                'css\\s*=\\s*"([^"]*)"', -- css="..."
                "css\\s*=\\s*{{([^}]*)}}", -- css={{...}}
                "css`([^`]*)`", -- css`...`
              },
            },
            lint = {
              cssConflict = "warning",
              invalidApply = "error",
              invalidScreen = "error",
              invalidVariant = "error",
              recommendedVariantOrder = "warning",
            },
          },
        },
      },
    },
  },
}
