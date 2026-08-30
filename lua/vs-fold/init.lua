-- vs-fold.nvim
--
-- Treesitter-based folding that mimics Visual Studio's default outlining:
-- folds functions/methods, classes, structs, unions, enums, namespaces, #if
-- blocks and statement blocks (if/else, for, while, do, switch/case), with a
-- VS-style fold text (`signature { ... }`).

local M = {}

local DEFAULTS = {
  -- Whether folding is enabled on startup
  enabled = true,

  -- Keymap to toggle folding on/off. Set to false to disable the default map.
  keymap = "<leader>zf",

  -- Visual Studio style: keep the '{' and show the body as "...}"
  foldtext_style = "vs",

  -- Show diagnostic icons (errors/warnings/etc.) in the fold text when a fold
  -- contains diagnostics, like VS Code's collapsed-region error indicator.
  foldtext_diagnostics = true,

  -- Also show the most severe diagnostic icon of a closed fold in the sign
  -- column (gutter), highlighted like VS Code's error bar indicator.
  fold_gutter_diagnostics = true,

  -- Leave a one-cell gap between the fold arrow (▸) and the gutter sign icon.
  fold_gutter_padding = true,

  diagnostics_icons = {
    [vim.diagnostic.severity.ERROR] = "✖",
    [vim.diagnostic.severity.WARN] = "⚠",
    [vim.diagnostic.severity.INFO] = "ℹ",
    [vim.diagnostic.severity.HINT] = "⚑",
  },

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

local SEVERITY_HL = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
  [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
}

local SEVERITY_ORDER = {
  [vim.diagnostic.severity.ERROR] = 1,
  [vim.diagnostic.severity.WARN] = 2,
  [vim.diagnostic.severity.INFO] = 3,
  [vim.diagnostic.severity.HINT] = 4,
}

-- Returns per-severity diagnostic counts intersecting lines [start0, end0]
-- (0-indexed), or nil when none.
local function diagnostics_in_range(diags, start0, end0)
  local counts = {}
  for _, d in ipairs(diags) do
    if d.lnum <= end0 and (d.end_lnum or d.lnum) >= start0 then
      local sev = d.severity or vim.diagnostic.severity.ERROR
      counts[sev] = (counts[sev] or 0) + 1
    end
  end
  if next(counts) then
    return counts
  end
  return nil
end

-- Returns the most severe severity value from a `diagnostics_in_range` result,
-- or nil.
local function highest_severity(counts)
  local best
  for sev in pairs(counts) do
    if not best or (SEVERITY_ORDER[sev] or 9) < (SEVERITY_ORDER[best] or 9) then
      best = sev
    end
  end
  return best
end

-- Returns virtual-text chunks (text + highlight group) for the diagnostics
-- contained inside the current fold, e.g. ` {icon.." 1", "DiagnosticSignError"}`.
-- Returns an empty list when the fold has none.
local function diagnostic_chunks()
  local cfg = M.config
  if not cfg.foldtext_diagnostics then
    return {}
  end

  local counts = diagnostics_in_range(vim.diagnostic.get(0), vim.v.foldstart - 1, vim.v.foldend - 1)
  if not counts then
    return {}
  end

  local sevs = {}
  for sev in pairs(counts) do
    sevs[#sevs + 1] = sev
  end
  table.sort(sevs, function(a, b)
    return (SEVERITY_ORDER[a] or 9) < (SEVERITY_ORDER[b] or 9)
  end)

  local chunks = {}
  for _, sev in ipairs(sevs) do
    local icon = cfg.diagnostics_icons[sev]
    if icon then
      chunks[#chunks + 1] = { "  ", "Folded" }
      chunks[#chunks + 1] = { icon .. " " .. counts[sev], SEVERITY_HL[sev] }
    end
  end
  return chunks
end

-- Returns the fold text for the current fold as a list of virtual-text chunks.
-- 'vs'   style: ` struct GameData { ... }`
-- 'count' style: ` struct GameData (14)`
function M.foldtext()
  local style = M.config.foldtext_style
  local lnum = vim.v.foldstart
  local lines = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)
  local text = lines[1] or ""
  text = text:gsub("%s+$", "")
  local result = {}
  if style == "count" then
    local count = vim.v.foldend - vim.v.foldstart + 1
    result[#result + 1] = { " " .. text .. " (" .. count .. ")", "Folded" }
  else
    -- vs style
    if not text:match("%{%s*$") then
      text = text .. " {"
    end
    result[#result + 1] = { " " .. text .. " ... }", "Folded" }
  end

  for _, chunk in ipairs(diagnostic_chunks()) do
    result[#result + 1] = chunk
  end
  return result
end

local function set_foldmethod(fm)
  vim.opt.foldmethod = fm
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    pcall(vim.api.nvim_win_set_option, win, "foldmethod", fm)
  end
end

local function apply_window_opts()
  local opt = vim.opt
  local cfg = M.config

  set_foldmethod(M.enabled and "expr" or "manual")
  if not M.enabled then
    return
  end

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

-- Sign namespace for the gutter diagnostic icons.
local sign_ns

local function clear_fold_signs(buf)
  vim.api.nvim_buf_clear_namespace(buf, sign_ns, 0, -1)
end

-- Places a sign with the most severe diagnostic icon on each closed fold that
-- contains diagnostics, for the lines currently visible in the window.
local function update_fold_signs()
  local cfg = M.config
  if not (cfg.fold_gutter_diagnostics and M.enabled) then
    clear_fold_signs(0)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local w0 = vim.fn.line("w0", win)
  local wlast = math.min(vim.fn.line("w$", win), vim.api.nvim_buf_line_count(buf))
  if wlast < w0 then
    return
  end

  local diags = vim.diagnostic.get(buf)
  if #diags == 0 then
    clear_fold_signs(buf)
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, sign_ns, 0, -1)

  local line = w0
  while line <= wlast do
    local start = vim.fn.foldclosed(line)
    if start == -1 then
      line = line + 1
    else
      local finish = vim.fn.foldclosedend(start)
      local counts = diagnostics_in_range(diags, start - 1, finish - 1)
      if counts then
        local sev = highest_severity(counts)
        local icon = sev and cfg.diagnostics_icons[sev]
        if icon then
          vim.api.nvim_buf_set_extmark(buf, sign_ns, start - 1, 0, {
            sign_text = (cfg.fold_gutter_padding and " " or "") .. icon,
            sign_hl_group = SEVERITY_HL[sev],
          })
        end
      end
      line = finish + 1
    end
  end
end

--- Enable or disable vs-fold. Folding can be turned on/off at any time.
---@param enabled boolean
---@return boolean the new enabled state
function M.setEnabled(enabled)
  M.enabled = enabled
  apply_window_opts()
  update_fold_signs()
  return M.enabled
end

--- Toggle vs-fold on/off.
---@return boolean the new enabled state
function M.toggle()
  return M.setEnabled(not M.enabled)
end

--- Setup vs-fold.nvim.
---@param opts table|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", DEFAULTS, opts or {})
  M.enabled = M.config.enabled

  if M.config.keymap then
    vim.keymap.set("n", M.config.keymap, M.toggle, { desc = "Toggle vs-fold.nvim" })
  end

  vim.api.nvim_create_user_command("VsFold", function(args)
    local arg = vim.trim(args.args)
    if arg == "" or arg == "toggle" then
      M.toggle()
    elseif arg == "on" then
      M.setEnabled(true)
    elseif arg == "off" then
      M.setEnabled(false)
    else
      vim.notify("Usage: VsFold [toggle|on|off]", vim.log.levels.ERROR)
    end
  end, { nargs = "?", desc = "Toggle VS-style treesitter folding" })

  sign_ns = vim.api.nvim_create_namespace("vs_fold_signs")

  local group = vim.api.nvim_create_augroup("vs_fold", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType", "BufRead", "BufNewFile" }, {
    group = group,
    callback = apply_window_opts,
  })
  vim.api.nvim_create_autocmd(
    { "CursorMoved", "WinScrolled", "BufEnter", "BufWinEnter", "BufReadPost", "BufWritePost", "FileType" },
    { group = group, callback = update_fold_signs }
  )
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = update_fold_signs,
  })

  apply_queries()
  apply_window_opts()
  update_fold_signs()
end

return M
