local M = {}

local function spellfile_status()
    local spellfiles = vim.opt_local.spellfile:get()
    local configured = spellfiles[1]
    if not configured or configured == "" then
        return nil, false
    end

    local target = vim.fn.fnamemodify(vim.fn.expand(configured), ":p")
    if vim.fn.filereadable(target) == 1 then
        return target, vim.fn.filewritable(target) == 1
    end

    local parent = vim.fs.dirname(target)
    local writable = vim.fn.isdirectory(parent) == 1
        and vim.fn.filewritable(parent) == 2
    return target, writable
end

function M.check()
    vim.health.start "spellfix.nvim"

    local loaded, spellfix = pcall(require, "spellfix")
    if loaded and type(spellfix) == "table" then
        vim.health.ok "spellfix is available"
    else
        vim.health.error("spellfix is not available", spellfix)
        return
    end

    if vim.fn.exists ":SpellFix" == 2 then
        vim.health.ok ":SpellFix is registered"
    else
        vim.health.error ":SpellFix is not registered"
    end

    for _, fn in ipairs { "spellbadword", "spellsuggest" } do
        if vim.fn.exists("*" .. fn) == 1 then
            vim.health.ok(fn .. "() is available")
        else
            vim.health.error(fn .. "() is not available")
        end
    end

    if
        type(vim.ui.select) == "function"
        and type(vim.ui.input) == "function"
    then
        vim.health.ok "vim.ui.select() and vim.ui.input() are available"
    else
        vim.health.error "vim.ui.select() or vim.ui.input() is unavailable"
    end

    local spellfile, writable = spellfile_status()
    if not spellfile then
        vim.health.warn(
            "'spellfile' is empty; the add action cannot persist words",
            "Set 'spellfile' to a writable *.add file"
        )
    elseif not writable then
        vim.health.warn(
            "'spellfile' target is not writable: " .. spellfile,
            "Create the file or make its parent directory writable"
        )
    else
        vim.health.info("Writable 'spellfile' target: " .. spellfile)
    end
end

return M
