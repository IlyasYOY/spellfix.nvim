local config = require "spellfix.config"
local Session = require "spellfix.session"

local M = {}
local active_sessions = {}

---@class spellfix.ReviewOpts
---@field winid? integer
---@field line1? integer
---@field line2? integer

local function is_integer(value)
    return type(value) == "number" and value == math.floor(value)
end

---@param opts? spellfix.Config
function M.setup(opts)
    config.setup(opts)
end

---@param opts? spellfix.ReviewOpts
---@return boolean started
---@return string? err
function M.review(opts)
    if opts == nil then
        opts = {}
    end
    if type(opts) ~= "table" then
        return false, "review options must be a table"
    end

    for name in pairs(opts) do
        if name ~= "winid" and name ~= "line1" and name ~= "line2" then
            return false, "unknown review option '" .. name .. "'"
        end
    end

    local winid = opts.winid or vim.api.nvim_get_current_win()
    if winid == 0 then
        winid = vim.api.nvim_get_current_win()
    end
    if not is_integer(winid) or not vim.api.nvim_win_is_valid(winid) then
        return false, "target window is invalid"
    end

    local bufnr = vim.api.nvim_win_get_buf(winid)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        return false, "target buffer is not loaded"
    end
    if not vim.bo[bufnr].modifiable then
        return false, "target buffer is not modifiable"
    end
    if active_sessions[bufnr] then
        return false, "a review is already active for this buffer"
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local line1 = opts.line1 or 1
    local line2 = opts.line2 or line_count
    if not is_integer(line1) or not is_integer(line2) then
        return false, "line bounds must be integers"
    end
    if line1 < 1 or line1 > line_count then
        return false, "line1 is outside the target buffer"
    end
    if line2 < line1 then
        return false, "line2 must not be before line1"
    end
    line2 = math.min(line2, line_count)

    local session
    session = Session.new {
        winid = winid,
        bufnr = bufnr,
        line1 = line1,
        line2 = line2,
        suggestion_count = config.suggestion_count(),
        on_finish = function()
            if active_sessions[bufnr] == session then
                active_sessions[bufnr] = nil
            end
        end,
    }
    active_sessions[bufnr] = session

    local ok, err = xpcall(function()
        session:start()
    end, debug.traceback)
    if not ok then
        active_sessions[bufnr] = nil
        session:finish(tostring(err), vim.log.levels.ERROR)
        return false, tostring(err)
    end

    return true
end

return M
