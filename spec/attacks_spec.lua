local fen = require("spec.support.fen")
local loader = require("spec.support.load_just_chess")

describe("attack generation", function()
    local namespace
    local JustChess
    local Internal
    local Attacks

    before_each(function()
        namespace = loader.load()
        JustChess = namespace.JustChess
        Internal = namespace.JustChessInternal
        Attacks = Internal.Attacks
    end)

    it("detects attacks by every piece kind", function()
        local cases = {
            { "7k/8/8/8/8/5n2/8/4K3 w - - 0 1", JustChess.Color.WHITE },
            { "7k/8/8/8/3p4/4K3/8/8 w - - 0 1", JustChess.Color.WHITE },
            { "7k/8/8/8/7b/8/5K2/8 w - - 0 1", JustChess.Color.WHITE },
            { "4r2k/8/8/8/8/8/8/4K3 w - - 0 1", JustChess.Color.WHITE },
            { "7k/8/8/8/1q6/8/3K4/8 w - - 0 1", JustChess.Color.WHITE },
            { "8/8/8/8/8/8/4k3/4K3 w - - 0 1", JustChess.Color.WHITE },
        }
        for index = 1, #cases do
            local position = fen.parse(cases[index][1], namespace)
            assert.is_true(Attacks.is_in_check(position, cases[index][2]))
        end
    end)
end)
