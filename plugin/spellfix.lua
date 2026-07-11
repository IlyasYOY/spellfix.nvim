if vim.g.loaded_spellfix then
    return
end
vim.g.loaded_spellfix = true

local spellfix = require "spellfix"

vim.api.nvim_create_user_command("SpellFix", function(opts)
    local started, err = spellfix.review {
        winid = 0,
        line1 = opts.line1,
        line2 = opts.line2,
    }
    if not started then
        vim.notify("SpellFix: " .. err, vim.log.levels.ERROR)
    end
end, {
    range = "%",
    desc = "Review spelling errors with an interactive picker",
})
