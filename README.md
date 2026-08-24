# spellfix.nvim

`spellfix.nvim` reviews Neovim spelling errors across a buffer or line range.
It uses the same syntax-aware spell scanner as Neovim, then presents suggested
replacements and review actions through `vim.ui.select`.

<img width="1574" height="1026" alt="Screenshot 2026-07-11 at 23 48 56" src="https://github.com/user-attachments/assets/6fce54f9-6c6e-4449-8410-d44f6c53c48d" />

## Requirements

- Neovim 0.11 or newer
- No required plugin dependencies

## Installation

With Neovim 0.12 or newer, use the built-in `vim.pack`:

```lua
vim.pack.add {
    { src = "https://github.com/IlyasYOY/spellfix.nvim" },
}
```

The plugin registers `:SpellFix` automatically. Calling `setup()` is optional.

Neovim 0.11 users should install the plugin with lazy.nvim or another package
manager.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "IlyasYOY/spellfix.nvim",
    opts = {
        suggestion_count = 10,
    },
}
```

## Configuration

```lua
require("spellfix").setup {
    suggestion_count = 10,
}
```

`suggestion_count` controls how many results from Neovim's `spellsuggest()`
are placed at the top of the picker.

## Usage

```vim
:SpellFix
:'<,'>SpellFix
```

Without a range, `:SpellFix` reviews the whole buffer. Each picker contains
suggested replacements followed by actions to enter a replacement, add the
word to `'spellfile'`, skip it once, skip every remaining occurrence during
the current review, or stop.

The plugin temporarily enables `'spell'` in the target window and restores its
original value when the review ends. It respects syntax regions configured
through `@Spell` and `@NoSpell`.

## Lua API

```lua
local spellfix = require "spellfix"

local started, err = spellfix.review {
    winid = 0,
    line1 = 1,
    line2 = vim.api.nvim_buf_line_count(0),
}

if not started then
    vim.notify(err, vim.log.levels.ERROR)
end
```

`review()` is asynchronous and defaults to the current window and its whole
buffer. Only one review may be active for a buffer at a time.

## Health

Run `:checkhealth spellfix` to verify the command, built-in spell functions,
UI functions, and the current buffer's first `spellfile` target. An empty or
unwritable target is reported as a warning because words selected with the add
action cannot be persisted.

See `:help spellfix` for the complete Vim help reference.

## Development

```sh
make help
make check
make test NVIM_VERSION=v0.11.7
make test NVIM_VERSION=v0.12.5
make test NVIM_VERSION=nightly
```

`make check` checks formatting, runs Luacheck, executes the isolated headless
Neovim test suite, and validates the tracked Vim help tags. Set `NVIM_VERSION`
to test a downloaded release, for example
`make test NVIM_VERSION=v0.11.7`.

## License

MIT
