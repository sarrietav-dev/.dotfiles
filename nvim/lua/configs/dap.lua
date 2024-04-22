return {
  mason_dap = {
    -- Makes a best effort to setup the various debuggers with
    -- reasonable debug configurations
    automatic_installation = false,

    -- You can provide additional configuration to the handlers,
    -- see mason-nvim-dap README for more information
    handlers = {
      function(config)
        -- all sources with no handler get passed here

        -- Keep original functionality
        require("mason-nvim-dap").default_setup(config)
      end,
      firefox = function(config)
        config.configurations = {
          {
            type = "firefox",
            request = "launch",
            name = "Firefox: Debug vite",
            webRoot = "${workspaceFolder}/client",
            url = "http://localhost:5173",
            profile = "dev-edition-default",
          },
          {
            type = "firefox",
            request = "launch",
            name = "Firefox: Debug CRA",
            webRoot = "${workspaceFolder}",
            url = "http://localhost:3000",
            profile = "dev-edition-default",
          },
          {
            type = "firefox",
            request = "launch",
            name = "Firefox: Debug storybook",
            webRoot = "${workspaceFolder}",
            url = "http://localhost:5173",
            profile = "dev-edition-default",
          },
        }
        require("mason-nvim-dap").default_setup(config) -- don't forget this!
      end,
    },

    -- You'll need to check that you have the required things installed
    -- online, please don't ask me how to install them :)
    ensure_installed = {
      -- Update this to ensure that you have the debuggers for the langs you want
      "delve",
      "node2",
      "chrome",
      "firefox",
      "js",
    },
  },
}
