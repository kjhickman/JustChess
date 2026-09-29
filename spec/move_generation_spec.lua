local fen = require("spec.support.fen")
local loader = require("spec.support.load_just_chess")

describe("legal move generation", function()
    local namespace
    local JustChess
    local Internal
    local MoveGeneration

    before_each(function()
        namespace = loader.load()
        JustChess = namespace.JustChess
        Internal = namespace.JustChessInternal
        MoveGeneration = Internal.MoveGeneration
    end)

    it("returns known legal move counts", function()
        local cases = {
            { "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", 20 },
            { "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 48 },
            { "R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w - - 0 1", 218 },
            { "4k3/8/8/3Pp3/8/8/8/4K3 w - e6 0 1", 7 },
            { "n1n5/PPPk4/8/8/8/8/4Kppp/5N1N b - - 0 1", 24 },
            { "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", 26 },
        }

        for index = 1, #cases do
            local position = fen.parse(cases[index][1], namespace)
            local count = MoveGeneration.write_legal_moves(position, {}, MoveGeneration.new_context())
            assert.equal(cases[index][2], count, cases[index][1])
            assert.equal(count, MoveGeneration.write_legal_moves(position, nil), cases[index][1])
        end
    end)

    it("does not castle from check through check or into check", function()
        local positions = {
            "4k3/8/8/8/8/8/4r3/4K2R w K - 0 1",
            "4kr2/8/8/8/8/8/8/4K2R w K - 0 1",
            "4k1r1/8/8/8/8/8/8/4K2R w K - 0 1",
        }

        for index = 1, #positions do
            local position = fen.parse(positions[index], namespace)
            local moves = {}
            local count = MoveGeneration.write_legal_moves(position, moves, MoveGeneration.new_context())
            for move_index = 1, count do
                assert.not_equal(Internal.SpecialMove.SHORT_CASTLE, Internal.Move.special_type(moves[move_index]))
            end
        end
    end)

    it("allocates no garbage after buffers are warm", function()
        local position = Internal.Position.new()
        local moves = {}
        local context = MoveGeneration.new_context()
        for _ = 1, 100 do
            MoveGeneration.write_legal_moves(position, moves, context)
        end

        collectgarbage("collect")
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 1000 do
            MoveGeneration.write_legal_moves(position, moves, context)
        end
        local after = collectgarbage("count")
        collectgarbage("restart")
        assert.equal(before, after)
    end)
end)
