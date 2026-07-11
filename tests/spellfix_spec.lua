local spellfix = require "spellfix"

local tests = {}
local case_number = 0

local function it(name, run)
    tests[#tests + 1] = { name = name, run = run }
end

local function fail(message)
    error(message, 2)
end

local function equal(expected, actual, message)
    if expected ~= actual then
        fail(
            message
                or ("expected %s, got %s"):format(
                    vim.inspect(expected),
                    vim.inspect(actual)
                )
        )
    end
end

local function truthy(value, message)
    if not value then
        fail(message or ("expected truthy value, got " .. vim.inspect(value)))
    end
end

local function contains(haystack, needle)
    truthy(
        tostring(haystack):find(needle, 1, true),
        ("expected %s to contain %s"):format(
            vim.inspect(haystack),
            vim.inspect(needle)
        )
    )
end

local function repo_root(path)
    local source = debug.getinfo(1, "S").source:sub(2)
    local root = vim.fn.fnamemodify(source, ":p:h:h")
    if not path then
        return root
    end
    return vim.fs.joinpath(root, path)
end

local function wait_for(predicate, message)
    truthy(vim.wait(2000, predicate, 10), message or "timed out")
end

local function find_choice(choices, kind, value)
    for _, choice in ipairs(choices) do
        if choice.kind == kind and (value == nil or choice.value == value) then
            return choice
        end
    end
    fail("choice not found: " .. kind .. " " .. tostring(value))
end

local function with_buffer(lines, run)
    case_number = case_number + 1
    local original_select = vim.ui.select
    local original_input = vim.ui.input
    local original_notify = vim.notify
    local original_win = vim.api.nvim_get_current_win()
    local original_buf = vim.api.nvim_get_current_buf()
    local original_spelllang = vim.o.spelllang
    local original_spellfile = vim.o.spellfile
    local test_dir = repo_root(".test-work/case-" .. case_number)
    local spellfile = vim.fs.joinpath(test_dir, "spell", "custom.utf-8.add")

    vim.fn.delete(test_dir, "rf")
    vim.fn.mkdir(vim.fs.dirname(spellfile), "p")

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(original_win, buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "text"
    vim.bo[buf].modifiable = true
    vim.wo[original_win].spell = false
    vim.bo[buf].spelllang = "en_us"
    vim.bo[buf].spellfile = spellfile

    local notifications = {}
    vim.notify = function(message, level)
        notifications[#notifications + 1] = {
            message = tostring(message),
            level = level,
        }
    end
    spellfix.setup()

    local ok, err = xpcall(function()
        run {
            buf = buf,
            win = original_win,
            notifications = notifications,
            spellfile = spellfile,
        }
    end, debug.traceback)

    vim.ui.select = original_select
    vim.ui.input = original_input
    vim.notify = original_notify
    vim.o.spelllang = original_spelllang
    vim.o.spellfile = original_spellfile
    pcall(vim.cmd, "syntax clear")
    if vim.api.nvim_buf_is_valid(original_buf) then
        vim.api.nvim_win_set_buf(original_win, original_buf)
    end
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
    end
    vim.fn.delete(test_dir, "rf")

    if not ok then
        error(err, 0)
    end
end

local function final_notification(context)
    return context.notifications[#context.notifications]
end

it("registers the public command", function()
    equal(2, vim.fn.exists ":SpellFix")
end)

it("validates configuration", function()
    local ok, err = pcall(spellfix.setup, { suggestion_count = 0 })
    equal(false, ok)
    contains(err, "positive integer")

    ok, err = pcall(spellfix.setup, { unknown = true })
    equal(false, ok)
    contains(err, "unknown setup option")
    spellfix.setup()
end)

it("replaces a suggestion through the command", function()
    with_buffer({ "The quik brown fox" }, function(context)
        vim.ui.select = function(choices, _, callback)
            callback(find_choice(choices, "replace", "quick"))
        end

        vim.cmd "SpellFix"
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(
            "The quick brown fox",
            vim.api.nvim_buf_get_lines(context.buf, 0, 1, false)[1]
        )
        contains(final_notification(context).message, "fixed 1")
        equal(false, vim.wo[context.win].spell)
    end)
end)

it("honors an explicit command range", function()
    with_buffer({ "quik", "mispeling" }, function(context)
        local prompts = 0
        vim.ui.select = function(choices, _, callback)
            prompts = prompts + 1
            callback(find_choice(choices, "skip_once"))
        end

        vim.cmd "1SpellFix"
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(1, prompts)
        contains(final_notification(context).message, "skipped 1")
    end)
end)

it("supports manual replacement after a multibyte prefix", function()
    with_buffer({ "🙂 quik" }, function(context)
        vim.ui.select = function(choices, _, callback)
            callback(find_choice(choices, "manual"))
        end
        vim.ui.input = function(_, callback)
            callback "quick"
        end

        vim.cmd "SpellFix"
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(
            "🙂 quick",
            vim.api.nvim_buf_get_lines(context.buf, 0, 1, false)[1]
        )
    end)
end)

it("returns to the picker when manual input is cancelled", function()
    with_buffer({ "quik" }, function(context)
        local prompts = 0
        vim.ui.select = function(choices, _, callback)
            prompts = prompts + 1
            if prompts == 1 then
                callback(find_choice(choices, "manual"))
            else
                callback(find_choice(choices, "stop"))
            end
        end
        vim.ui.input = function(_, callback)
            callback(nil)
        end

        vim.cmd "SpellFix"
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(2, prompts)
        contains(final_notification(context).message, "stopped")
    end)
end)

it("distinguishes skip once from skip all", function()
    with_buffer({ "quik quik quik" }, function(context)
        local prompts = 0
        vim.ui.select = function(choices, _, callback)
            prompts = prompts + 1
            if prompts == 1 then
                callback(find_choice(choices, "skip_once"))
            else
                callback(find_choice(choices, "skip_all"))
            end
        end

        vim.cmd "SpellFix"
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(2, prompts)
        contains(final_notification(context).message, "skipped 3")
    end)
end)

it("adds a word to the persistent spellfile", function()
    with_buffer({ "blorptastic blorptastic" }, function(context)
        local prompts = 0
        vim.ui.select = function(choices, _, callback)
            prompts = prompts + 1
            callback(find_choice(choices, "add"))
        end

        vim.cmd "SpellFix"
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(1, prompts)
        truthy(vim.fn.filereadable(context.spellfile) == 1)
        contains(
            table.concat(vim.fn.readfile(context.spellfile), "\n"),
            "blorptastic"
        )
        contains(final_notification(context).message, "added 1")
    end)
end)

it("ignores syntax regions excluded from spell checking", function()
    with_buffer({ "A quik `mispeling`" }, function(context)
        vim.bo[context.buf].filetype = "markdown"
        vim.bo[context.buf].syntax = "markdown"

        local words = {}
        vim.ui.select = function(choices, opts, callback)
            words[#words + 1] = opts.prompt
            callback(find_choice(choices, "skip_once"))
        end

        vim.cmd "SpellFix"
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(1, #words)
        contains(words[1], "quik")
    end)
end)

it("does not apply a stale picker result", function()
    with_buffer({ "quik" }, function(context)
        local pending
        local choices
        vim.ui.select = function(items, _, callback)
            choices = items
            pending = callback
        end

        vim.cmd "SpellFix"
        wait_for(function()
            return pending ~= nil
        end)
        vim.api.nvim_buf_set_lines(context.buf, 0, 1, false, { "changed" })
        pending(find_choice(choices, "replace", "quick"))
        wait_for(function()
            return #context.notifications > 0
        end)

        equal(
            "changed",
            vim.api.nvim_buf_get_lines(context.buf, 0, 1, false)[1]
        )
        contains(final_notification(context).message, "buffer changed")
    end)
end)

it("rejects duplicate sessions and unmodifiable buffers", function()
    with_buffer({ "quik" }, function(context)
        local pending
        local choices
        vim.ui.select = function(items, _, callback)
            choices = items
            pending = callback
        end

        local started = spellfix.review()
        truthy(started)
        local err
        started, err = spellfix.review()
        equal(false, started)
        contains(err, "already active")

        pending(find_choice(choices, "stop"))
        wait_for(function()
            return #context.notifications > 0
        end)

        vim.bo[context.buf].modifiable = false
        started, err = spellfix.review()
        equal(false, started)
        contains(err, "not modifiable")
        vim.bo[context.buf].modifiable = true
    end)
end)

it("restores the original cursor when no errors exist", function()
    with_buffer(
        { "The quick brown fox", "Another correct line" },
        function(context)
            vim.api.nvim_win_set_cursor(context.win, { 1, 4 })
            vim.cmd "SpellFix"
            wait_for(function()
                return #context.notifications > 0
            end)

            equal(1, vim.api.nvim_win_get_cursor(context.win)[1])
            equal(4, vim.api.nvim_win_get_cursor(context.win)[2])
            contains(final_notification(context).message, "no spelling errors")
        end
    )
end)

return tests
