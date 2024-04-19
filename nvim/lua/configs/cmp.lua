local cmp = require "cmp"
local cmp_ui = require("nvconfig").ui.cmp
local cmp_style = cmp_ui.style

local field_arrangement = {
  atom = { "kind", "abbr", "menu" },
  atom_colored = { "kind", "abbr", "menu" },
}

local formatting_style = {
  -- default fields order i.e completion word + item.kind + item.kind icons
  fields = field_arrangement[cmp_style] or { "abbr", "kind", "menu" },

  format = function(entry, item)
    local icons = require "nvchad.icons.lspkind"
    local icon = (cmp_ui.icons and icons[item.kind]) or ""

    if cmp_style == "atom" or cmp_style == "atom_colored" then
      icon = " " .. icon .. " "
      item.menu = cmp_ui.lspkind_text and "   (" .. item.kind .. ")" or ""
      item.kind = icon
    else
      icon = cmp_ui.lspkind_text and (" " .. icon .. " ") or icon
      item.kind = string.format("%s %s", icon, cmp_ui.lspkind_text and item.kind or "")
    end

    return require("tailwindcss-colorizer-cmp").formatter(entry, item)
  end,
}

local has_words_before = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
    return false
  end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match "^%s*$" == nil
end

local tab = function(fallback)
  if cmp.visible() and has_words_before() then
    cmp.select_next_item()
  elseif require("luasnip").expand_or_jumpable() then
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true), "")
  else
    fallback()
  end
end

local opts = function()
  local nvchad_ops = require "nvchad.configs.cmp"
  nvchad_ops.formatting = formatting_style
  table.insert(nvchad_ops.sources, 1, {
    name = "copilot",
    group_index = 1,
    priority = 100,
  })

  nvchad_ops.mapping["<Tab>"] = cmp.mapping(tab, { "i", "s" })

  return nvchad_ops
end

return opts
