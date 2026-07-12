local spellfix = require "spellfix"

describe("spellfix API", function()
    it("validates review options without starting a session", function()
        local started, err = spellfix.review "invalid"
        assert.is_false(started)
        assert.truthy(err:find("must be a table", 1, true))

        started, err = spellfix.review { unknown = true }
        assert.is_false(started)
        assert.truthy(err:find("unknown review option", 1, true))

        started, err = spellfix.review { line1 = 0 }
        assert.is_false(started)
        assert.truthy(err:find("line1 is outside", 1, true))
    end)
end)
