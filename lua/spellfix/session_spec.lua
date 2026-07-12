local Session = require "spellfix.session"

describe("spellfix.session", function()
    local bufnr
    local winid
    local original_buf
    local original_notify

    before_each(function()
        winid = vim.api.nvim_get_current_win()
        original_buf = vim.api.nvim_win_get_buf(winid)
        original_notify = vim.notify
        vim.notify = function() end
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(winid, bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "text" })
        vim.api.nvim_win_set_cursor(winid, { 1, 2 })
        vim.wo[winid].spell = false
    end)

    after_each(function()
        vim.notify = original_notify
        if vim.api.nvim_buf_is_valid(original_buf) then
            vim.api.nvim_win_set_buf(winid, original_buf)
        end
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end)

    it("restores state and finishes once", function()
        local finished = 0
        local session = Session.new {
            winid = winid,
            bufnr = bufnr,
            line1 = 1,
            line2 = 1,
            suggestion_count = 5,
            on_finish = function()
                finished = finished + 1
            end,
        }

        vim.wo[winid].spell = true
        vim.api.nvim_win_set_cursor(winid, { 1, 0 })
        session:finish "done"
        session:finish "done again"

        assert.equal(1, finished)
        assert.is_false(vim.wo[winid].spell)
        assert.same({ 1, 2 }, vim.api.nvim_win_get_cursor(winid))
    end)

    it("tracks byte-oriented scan advancement", function()
        local session = Session.new {
            winid = winid,
            bufnr = bufnr,
            line1 = 1,
            line2 = 1,
            suggestion_count = 5,
            on_finish = function() end,
        }
        session:advance(1, 3, "word")
        assert.equal(1, session.line)
        assert.equal(7, session.col)
    end)
end)
