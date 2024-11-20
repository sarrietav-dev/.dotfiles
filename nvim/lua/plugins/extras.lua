local function import_plugins(category, plugins)
  local result = {}
  for _, plugin in ipairs(plugins) do
    table.insert(result, { import = "lazyvim.plugins.extras." .. category .. "." .. plugin })
  end
  return result
end

return {
  -- AI Plugins
  unpack(import_plugins("ai", {
    "copilot",
    "copilot-chat",
  })),

  -- Coding Plugins
  unpack(import_plugins("coding", {
    "mini-surround",
    "yanky",
  })),

  -- DAP Plugins
  unpack(import_plugins("dap", {
    "core",
    "nlua",
  })),

  -- Editor Plugins
  unpack(import_plugins("editor", {
    "dial",
    "inc-rename",
    "telescope",
  })),

  -- Test Plugins
  unpack(import_plugins("test", {
    "core",
  })),

  -- Utility Plugins
  unpack(import_plugins("util", {
    "mini-hipatterns",
  })),

  -- Language Plugins
  unpack(import_plugins("lang", {
    "angular",
    "astro",
    "docker",
    "git",
    "go",
    "java",
    "json",
    "markdown",
    "omnisharp",
    "php",
    "python",
    "rust",
    "sql",
    "svelte",
    "tailwind",
    "terraform",
    "toml",
    "typescript",
    "vue",
    "yaml",
  })),
}
