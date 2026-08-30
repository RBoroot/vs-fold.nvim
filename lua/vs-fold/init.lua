-- vs-fold.nvim
--
-- Treesitter-based folding that mimics Visual Studio's default outlining:
-- folds functions/methods, classes, structs, unions, enums, namespaces, #if
-- blocks and statement blocks (if/else, for, while, do, switch/case), with a
-- VS-style fold text (`signature { ... }`).

local M = {}

local DEFAULTS = {
  -- Visual Studio style: keep the '{' and show the body as "...}"
  foldtext_style = "vs",

  -- foldmarkers: use ▸/▾ in the fold column instead of +/- from the default
  foldmarkers = true,

  -- Hide numeric fold-nesting levels when the fold column is too narrow.
  -- nvim otherwise shows digits (e.g. "4", "2") for deeply nested folds.
  foldinner = " ",

  -- Window-local folding options
  foldcolumn = "auto:1",
  foldnestmax = 5, -- allow nested outline items (methods inside classes), like VS's tree
  foldlevel = 99,  -- open all folds by default, fold on demand (zc/zo)

  -- languages enabled for VS-style fold queries (node types for each)
  langs = {
    cpp = [[
      (function_definition) @fold
      (struct_specifier) @fold
      (class_specifier) @fold
      (union_specifier) @fold
      (enum_specifier) @fold
      (namespace_definition) @fold
      (preproc_if) @fold
      (if_statement) @fold
      (for_statement) @fold
      (for_range_loop) @fold
      (while_statement) @fold
      (do_statement) @fold
      (switch_statement) @fold
      (case_statement) @fold
    ]],
    -- plain C has no classes/namespaces/range-for; using those node types
    -- would make the whole query fail to compile for the C grammar
    c = [[
      (function_definition) @fold
      (struct_specifier) @fold
      (union_specifier) @fold
      (enum_specifier) @fold
      (preproc_if) @fold
      (if_statement) @fold
      (for_statement) @fold
      (while_statement) @fold
      (do_statement) @fold
      (switch_statement) @fold
      (case_statement) @fold
    ]],
  },
}

-- Returns the fold text for the current fold.
-- 'vs'   style: ` struct GameData { ... }`
-- 'count' style: ` struct GameData (14)`
function M.foldtext()
  local style = M.config.foldtext_style
  local lnum = vim.v.foldstart
  local lines = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)
  local text = lines[1] or ""
  text = text:gsub("%s+$", "")
  if style == "count" then
    local count = vim.v.foldend - vim.v.foldstart + 1
    return " " .. text .. " (" .. count .. ")"
  end
  -- vs style
  if not text:match("%{%s*$") then
    text = text .. " {"
  end
  return " " .. text .. " ... }"
end

local function apply_window_opts()
  local opt = vim.opt
  local cfg = M.config

  opt.foldmethod = "expr"
  opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  opt.foldnestmax = cfg.foldnestmax
  opt.foldlevel = cfg.foldlevel
  opt.foldcolumn = cfg.foldcolumn
  opt.foldtext = "v:lua.require('vs-fold').foldtext()"

  if cfg.foldmarkers then
    local fc = vim.opt.fillchars:get()
    fc.foldopen = "▾"
    fc.foldclose = "▸"
    fc.fold = " "
    if cfg.foldinner ~= false then
      fc.foldinner = cfg.foldinner
    end
    vim.opt.fillchars = fc
  end
end

local function apply_queries()
  for lang, query in pairs(M.config.langs) do
    pcall(vim.treesitter.query.set, lang, "folds", query)
  end
end

--- Setup vs-fold.nvim.
---@param opts table|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", DEFAULTS, opts or {})

  vim.api.nvim_create_autocmd({ "FileType", "BufRead", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("vs_fold", { clear = true }),
    callback = apply_window_opts,
  })

  apply_queries()
end

return M
