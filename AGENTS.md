# spellfix.nvim Agent Guidelines

## Project shape

- The public Lua API lives in `lua/spellfix/init.lua`.
- Review-session behavior lives in `lua/spellfix/session.lua`.
- Automatic `:SpellFix` registration lives in `plugin/spellfix.lua`.
- Tests run in isolated project and XDG directories under ignored test paths.
- The plugin has no runtime dependencies beyond Neovim.

## Compatibility

- Support Neovim 0.11 and newer.
- Preserve syntax-aware spell scanning through Neovim's `spellbadword()`.
- Preserve the command and Lua API documented in `README.md`.
- Keep `vim.ui.select` and `vim.ui.input` as the UI integration points.

## Commands

- `make check` runs the canonical formatting, lint, and test suite.
- `make test` runs tests with the current `nvim`.
- `make test NVIM_VERSION=v0.11.7` runs tests with a downloaded release.
- `make format` formats Lua sources.

Do not commit or push changes unless the user explicitly asks.

