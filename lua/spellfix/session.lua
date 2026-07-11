local Session = {}
Session.__index = Session

local ACTIONS = {
    manual = "Enter replacement…",
    add = "Add to spellfile",
    skip_once = "Skip once",
    skip_all = "Skip all occurrences",
    stop = "Stop review",
}

---@param callback fun()
function Session:schedule(callback)
    vim.schedule(function()
        if self.finished then
            return
        end
        local ok, err = xpcall(callback, debug.traceback)
        if not ok then
            self:finish(tostring(err), vim.log.levels.ERROR)
        end
    end)
end

---@class spellfix.SessionOpts
---@field winid integer
---@field bufnr integer
---@field line1 integer
---@field line2 integer
---@field suggestion_count integer
---@field on_finish fun()

---@param opts spellfix.SessionOpts
---@return table
function Session.new(opts)
    local self = setmetatable({}, Session)
    self.winid = opts.winid
    self.bufnr = opts.bufnr
    self.line1 = opts.line1
    self.line2 = opts.line2
    self.suggestion_count = opts.suggestion_count
    self.on_finish = opts.on_finish
    self.line = opts.line1
    self.col = 0
    self.fixed = 0
    self.added = 0
    self.skipped = 0
    self.skipped_words = {}
    self.finished = false
    self.found_error = false
    self.original_cursor = vim.api.nvim_win_get_cursor(self.winid)
    self.original_spell = vim.wo[self.winid].spell
    return self
end

---@return boolean
function Session:is_active()
    return vim.api.nvim_win_is_valid(self.winid)
        and vim.api.nvim_buf_is_valid(self.bufnr)
        and vim.api.nvim_buf_is_loaded(self.bufnr)
        and vim.api.nvim_win_get_buf(self.winid) == self.bufnr
end

---@param status string
---@param level? integer
function Session:finish(status, level)
    if self.finished then
        return
    end
    self.finished = true

    if vim.api.nvim_win_is_valid(self.winid) then
        vim.wo[self.winid].spell = self.original_spell
        if
            not self.found_error
            and vim.api.nvim_win_get_buf(self.winid) == self.bufnr
        then
            pcall(vim.api.nvim_win_set_cursor, self.winid, self.original_cursor)
        end
    end

    pcall(self.on_finish)
    vim.notify(
        string.format(
            "SpellFix: %s (fixed %d, added %d, skipped %d)",
            status,
            self.fixed,
            self.added,
            self.skipped
        ),
        level or vim.log.levels.INFO
    )
end

---@param line integer
---@param col integer
---@param text string
function Session:advance(line, col, text)
    self.line = line
    self.col = col + math.max(#text, 1)
end

---@param expected_tick integer
---@return boolean
function Session:validate_callback(expected_tick)
    if self.finished then
        return false
    end
    if not self:is_active() then
        self:finish("target window changed", vim.log.levels.WARN)
        return false
    end
    if vim.api.nvim_buf_get_changedtick(self.bufnr) ~= expected_tick then
        self:finish("buffer changed", vim.log.levels.WARN)
        return false
    end
    return true
end

---@param word string
---@param line integer
---@param col integer
---@return boolean
function Session:word_is_current(word, line, col)
    local current = vim.api.nvim_buf_get_text(
        self.bufnr,
        line - 1,
        col,
        line - 1,
        col + #word,
        {}
    )
    return current[1] == word
end

---@param word string
---@param line integer
---@param col integer
---@param replacement string
function Session:replace(word, line, col, replacement)
    if not self:word_is_current(word, line, col) then
        self:finish("word changed", vim.log.levels.WARN)
        return
    end

    local ok, err = pcall(
        vim.api.nvim_buf_set_text,
        self.bufnr,
        line - 1,
        col,
        line - 1,
        col + #word,
        { replacement }
    )
    if not ok then
        self:finish(tostring(err), vim.log.levels.ERROR)
        return
    end

    self.fixed = self.fixed + 1
    self:advance(line, col, replacement)
    self:schedule(function()
        self:step()
    end)
end

---@param context table
function Session:prompt(context)
    if self.finished then
        return
    end

    local ok, suggestions = pcall(vim.api.nvim_win_call, self.winid, function()
        return vim.fn.spellsuggest(
            context.word,
            self.suggestion_count,
            context.kind == "caps"
        )
    end)
    if not ok then
        self:finish(tostring(suggestions), vim.log.levels.ERROR)
        return
    end

    local choices = {}
    for _, suggestion in ipairs(suggestions) do
        choices[#choices + 1] = {
            kind = "replace",
            label = "Replace with “" .. suggestion .. "”",
            value = suggestion,
        }
    end
    for _, kind in ipairs { "manual", "add", "skip_once", "skip_all", "stop" } do
        choices[#choices + 1] = {
            kind = kind,
            label = ACTIONS[kind],
        }
    end

    local expected_tick = vim.api.nvim_buf_get_changedtick(self.bufnr)
    local select_ok, select_err = pcall(vim.ui.select, choices, {
        prompt = string.format(
            "SpellFix: %s (%s) at %d:%d",
            context.word,
            context.kind,
            context.line,
            context.col + 1
        ),
        format_item = function(choice)
            return choice.label
        end,
    }, function(choice)
        self:schedule(function()
            self:handle_choice(context, expected_tick, choice)
        end)
    end)
    if not select_ok then
        self:finish(tostring(select_err), vim.log.levels.ERROR)
    end
end

---@param context table
---@param expected_tick integer
function Session:prompt_manual(context, expected_tick)
    local input_ok, input_err = pcall(vim.ui.input, {
        prompt = "SpellFix replacement for " .. context.word .. ": ",
        default = context.word,
    }, function(replacement)
        self:schedule(function()
            if not self:validate_callback(expected_tick) then
                return
            end
            if replacement == nil or replacement == "" then
                self:prompt(context)
                return
            end
            self:replace(context.word, context.line, context.col, replacement)
        end)
    end)
    if not input_ok then
        self:finish(tostring(input_err), vim.log.levels.ERROR)
    end
end

---@param context table
function Session:add_to_spellfile(context)
    local ok, err = pcall(vim.api.nvim_win_call, self.winid, function()
        vim.cmd.spellgood { args = { context.word } }
    end)
    if not ok then
        vim.notify(
            "SpellFix: failed to add word: " .. tostring(err),
            vim.log.levels.ERROR
        )
        self:prompt(context)
        return
    end

    self.added = self.added + 1
    self:advance(context.line, context.col, context.word)
    self:schedule(function()
        self:step()
    end)
end

---@param context table
---@param expected_tick integer
---@param choice? table
function Session:handle_choice(context, expected_tick, choice)
    if not self:validate_callback(expected_tick) then
        return
    end
    if not choice or choice.kind == "stop" then
        self:finish "stopped"
        return
    end
    if not self:word_is_current(context.word, context.line, context.col) then
        self:finish("word changed", vim.log.levels.WARN)
        return
    end

    vim.api.nvim_win_set_cursor(self.winid, { context.line, context.col })

    if choice.kind == "replace" then
        self:replace(context.word, context.line, context.col, choice.value)
        return
    end
    if choice.kind == "manual" then
        self:prompt_manual(context, expected_tick)
        return
    end
    if choice.kind == "add" then
        self:add_to_spellfile(context)
        return
    end

    self.skipped = self.skipped + 1
    if choice.kind == "skip_all" then
        self.skipped_words[context.word] = true
    end
    self:advance(context.line, context.col, context.word)
    self:schedule(function()
        self:step()
    end)
end

function Session:step()
    if self.finished then
        return
    end
    if not self:is_active() then
        self:finish("target window changed", vim.log.levels.WARN)
        return
    end

    local range_end =
        math.min(self.line2, vim.api.nvim_buf_line_count(self.bufnr))
    while self.line <= range_end do
        local line_text = vim.api.nvim_buf_get_lines(
            self.bufnr,
            self.line - 1,
            self.line,
            false
        )[1] or ""

        if self.col > #line_text then
            self.line = self.line + 1
            self.col = 0
        else
            local col = math.min(self.col, #line_text)
            local ok, bad = pcall(vim.api.nvim_win_call, self.winid, function()
                vim.api.nvim_win_set_cursor(self.winid, { self.line, col })
                return vim.fn.spellbadword()
            end)
            if not ok then
                self:finish(tostring(bad), vim.log.levels.ERROR)
                return
            end

            local word = bad[1]
            if word == "" then
                self.line = self.line + 1
                self.col = 0
            else
                local position = vim.api.nvim_win_get_cursor(self.winid)
                local word_line = position[1]
                local word_col = position[2]
                if word_line ~= self.line or word_col < self.col then
                    self.line = self.line + 1
                    self.col = 0
                else
                    self.found_error = true
                    if self.skipped_words[word] then
                        self.skipped = self.skipped + 1
                        self:advance(word_line, word_col, word)
                    else
                        self:prompt {
                            word = word,
                            kind = bad[2],
                            line = word_line,
                            col = word_col,
                        }
                        return
                    end
                end
            end
        end
    end

    if self.found_error then
        self:finish "done"
    else
        self:finish "no spelling errors"
    end
end

function Session:start()
    vim.wo[self.winid].spell = true
    self:step()
end

return Session
