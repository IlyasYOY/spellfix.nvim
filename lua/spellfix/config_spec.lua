local config = require "spellfix.config"

describe("spellfix.config", function()
    before_each(function()
        config.setup()
    end)

    after_each(function()
        config.setup()
    end)

    it("uses defaults and applies valid options", function()
        assert.equal(5, config.suggestion_count())
        config.setup { suggestion_count = 12 }
        assert.equal(12, config.suggestion_count())
        config.setup()
        assert.equal(5, config.suggestion_count())
    end)

    it("rejects unknown and invalid options", function()
        assert.has_error(function()
            config.setup { unknown = true }
        end, "unknown setup option")
        assert.has_error(function()
            config.setup { suggestion_count = 0 }
        end, "positive integer")
        assert.has_error(function()
            config.setup { suggestion_count = 1.5 }
        end, "positive integer")
    end)
end)
