# vs-fold.nvim

Treesitter-based folding for Neovim that mimics **Visual Studio's default outlining**.
It folds the same constructs VS does — methods/functions, classes, structs, unions,
enums, namespaces, `#if` blocks, and statement blocks (`if/else`, `for`, `while`,
`do`, `switch/case`) — and renders the collapsed text in VS style: `int main() { ... }`.

## Requirements

- Neovim 0.10+ (uses `vim.treesitter.foldexpr()` and custom `folds` queries)
- A plugin manager (lazy.nvim, packer, etc.)

## Installation

### lazy.nvim

```lua
{
  "RBoroot/vs-fold.nvim",
  config = function()
    require("vs-fold").setup()
  end,
}
```

Since it relies on treesitter, make sure `nvim-treesitter` (or `vim.treesitter`)
is installed with the `c` and `cpp` parsers.

## Usage

Call `setup()` once. It:

- sets `foldmethod = "expr"`, `foldexpr`, `foldtext`, and the fold gutter options
- overrides the `folds` query for C/C++ so only VS-style outlines create folds
- sets `▸` / `▾` fold markers and hides the numeric nesting-level digits

Toggle folds with the usual keys: `zc` (fold close), `zo` (open), `za` (toggle),
`zM` (close all), `zR` (open all).

To turn VS-style folding itself on/off:

- `:VsFold` or `:VsFold toggle` — toggle
- `:VsFold on` / `:VsFold off` — force on/off
- `<leader>zf` (default keymap, configurable) — toggle
- `require("vs-fold").toggle()` / `require("vs-fold").setEnabled(true|false)`

## Options

```lua
require("vs-fold").setup({
  -- Start with folding on (true) or off (false). Default: true
  enabled = true,

  -- Keymap to toggle folding. Set to false to disable the default map.
  keymap = "<leader>zf",

  -- Show diagnostic icons in the fold text when a fold contains errors/warnings/etc.
  -- (like VS Code's collapsed-region indicator). Set to false to disable.
  foldtext_diagnostics = true,
  -- Also show the most severe diagnostic icon of a closed fold in the sign
  -- column (gutter), like VS Code's error bar indicator.
  fold_gutter_diagnostics = true,
  -- Leave a one-cell gap between the fold arrow (▸) and the gutter sign icon.
  fold_gutter_padding = true,
  -- Icons per severity; set an entry to false to hide that severity.
  diagnostics_icons = {
    [4] = "✖", -- ERROR (vim.diagnostic.severity.ERROR)
    [3] = "⚠", -- WARN
    [2] = "ℹ", -- INFO
    [1] = "⚑", -- HINT
  },

  -- "vs"   -> ` int main() { ... }`
  -- "count"-> ` int main() (11)`
  -- with diagnostics: ` int main() { ... }  ✖1 ⚠2`
  foldtext_style = "vs",

  -- Use ▸/▾ markers instead of the default +/- in the fold column
  foldmarkers = true,

  -- Character shown for inner fold nesting levels (replaces numeric digits).
  -- Set to false to leave nvim's default digit behavior.
  foldinner = " ",

  foldcolumn = "auto:1",
  foldnestmax = 5, -- allow nested outline items (methods inside classes)
  foldlevel = 99,  -- open all folds by default

  -- Override the folds query per language (treesitter query text).
  -- Only define node types that exist in the target grammar, or the whole
  -- query will fail to compile and folding will silently stop working.
  langs = {
    cpp = "((function_definition) @fold\n (while_statement) @fold\n)",
    c = "((function_definition) @fold\n)",
  },
})
```

## License

MIT
