return function()
  local defaults = require("outline.config").defaults
  local opts = {
    symbols = {},
    symbol_blacklist = {},
  }

  for kind, symbol in pairs(defaults.symbols) do
    opts.symbols[kind] = {
      icon = symbol.icon,
      hl = symbol.hl,
    }
  end
  return opts
end
