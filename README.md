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
  "your-user/vs-fold.nvim",
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

## Options

```lua
require("vs-fold").setup({
  -- "vs"   -> ` int main() { ... }`
  -- "count"-> ` int main() (11)`
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
