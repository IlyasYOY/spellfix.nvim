# spellfix.nvim Agent Guidelines

## Scope and compatibility

- Support Neovim 0.11 and newer.
- Preserve `:SpellFix`, explicit range handling, setup options, and the Lua
  API documented in `README.md` and `doc/spellfix.txt`.
- Preserve asynchronous review and syntax-aware scanning through Neovim's
  `spellbadword()`.
- Keep `vim.ui.select()` and `vim.ui.input()` as the UI integration points.
- Preserve buffer changedtick checks, single-session ownership, spellfile
  writes, and restoration of window spell state and cursor position.

## Repository structure

- Runtime modules and focused config, session, API, and health specs live
  together under `lua/spellfix/`.
- Automatic command registration remains in `plugin/spellfix.lua`.
- Startup-command and end-to-end review coverage remains under `tests/`.
- Vim help lives in `doc/spellfix.txt`; keep `doc/tags` synchronized.
- Isolate XDG state, logs, spellfiles, and test buffers under ignored
  `.test-home/` and `.test-work/`.

## Development commands

- `make check` is the canonical non-mutating lint, test, and help check.
- `make test NVIM_VERSION=v0.11.7` verifies minimum compatibility.
- `make test NVIM_VERSION=v0.12.5` verifies current stable compatibility.
- `make test NVIM_VERSION=nightly` is the non-blocking CI probe.
- `make format` formats Lua sources.

Do not commit, push, tag, or publish unless the user explicitly asks.
