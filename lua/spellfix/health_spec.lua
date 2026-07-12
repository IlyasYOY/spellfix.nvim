local health = require "spellfix.health"

local function capture_health()
    local reports = {}
    local captured = {}
    for _, level in ipairs { "start", "ok", "warn", "error", "info" } do
        captured[level] = function(message, advice)
            reports[#reports + 1] = {
                level = level,
                message = tostring(message),
                advice = advice,
            }
        end
    end
    return captured, reports
end

local function has_report(reports, level, text)
    for _, report in ipairs(reports) do
        if report.level == level and report.message:find(text, 1, true) then
            return true
        end
    end
    return false
end

describe("spellfix.health", function()
    local original_health
    local original_spellfile

    before_each(function()
        original_health = vim.health
        original_spellfile = vim.bo.spellfile
    end)

    after_each(function()
        vim.health = original_health
        vim.bo.spellfile = original_spellfile
    end)

    it("reports command, spell APIs, UI, and a writable spellfile", function()
        local captured, reports = capture_health()
        vim.health = captured
        vim.bo.spellfile =
            vim.fs.joinpath(vim.fn.getcwd(), ".test-work", "health.utf-8.add")
        health.check()

        assert.is_true(has_report(reports, "start", "spellfix.nvim"))
        assert.is_true(has_report(reports, "ok", ":SpellFix is registered"))
        assert.is_true(has_report(reports, "ok", "spellbadword()"))
        assert.is_true(
            has_report(reports, "info", "Writable 'spellfile' target")
        )
    end)

    it("warns when spellfile is empty", function()
        local captured, reports = capture_health()
        vim.health = captured
        vim.bo.spellfile = ""
        health.check()
        assert.is_true(has_report(reports, "warn", "'spellfile' is empty"))
    end)

    it("warns when the spellfile parent is unavailable", function()
        local captured, reports = capture_health()
        vim.health = captured
        local missing_parent = vim.fs.joinpath(
            vim.fn.getcwd(),
            ".test-work",
            "missing-health-parent"
        )
        vim.fn.delete(missing_parent, "rf")
        vim.bo.spellfile = vim.fs.joinpath(missing_parent, "words.utf-8.add")

        health.check()

        assert.is_true(
            has_report(reports, "warn", "'spellfile' target is not writable")
        )
    end)
end)
