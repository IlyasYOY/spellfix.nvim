local M = {}

local defaults = {
    suggestion_count = 5,
}

local config = {}

local function is_positive_integer(value)
    return type(value) == "number" and value > 0 and value == math.floor(value)
end

---@class spellfix.Config
---@field suggestion_count? integer

---@param opts? spellfix.Config
function M.setup(opts)
    if opts == nil then
        opts = {}
    end
    if type(opts) ~= "table" then
        error("spellfix: setup options must be a table", 0)
    end

    for name, value in pairs(opts) do
        if name ~= "suggestion_count" then
            error("spellfix: unknown setup option '" .. name .. "'", 0)
        end
        if not is_positive_integer(value) then
            error("spellfix: suggestion_count must be a positive integer", 0)
        end
    end

    config = vim.tbl_extend("force", {}, defaults, opts)
end

---@return integer
function M.suggestion_count()
    return config.suggestion_count
end

M.setup()

return M
