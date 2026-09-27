local fen = require("spec.support.fen")
local loader = require("spec.support.load_just_chess")

describe("game API", function()
    local namespace
    local JustChess
    local Internal

    before_each(function()
        namespace = loader.load()
        JustChess = namespace.JustChess
        Internal = namespace.JustChessInternal
    end)

    it("creates a standard game and answers board queries", function()
        local game = JustChess.new_game()

        assert.equal(JustChess.Color.WHITE, game:side_to_move())
        assert.equal(JustChess.Piece.WHITE_KING, game:piece_at(JustChess.Square.E1))
        assert.equal(JustChess.Piece.BLACK_PAWN, game:piece_at(JustChess.Square.A7))
        assert.is_nil(game:piece_at(JustChess.Square.E4))
        assert.is_false(game:is_in_check())
        assert.equal("ongoing", game:status())
        assert.equal(20, #game:get_legal_moves())
        assert.equal(2, #game:get_legal_moves(JustChess.Square.E2))
    end)

    it("writes moves into caller-owned buffers", function()
        local game = JustChess.new_game()
        local moves = {}

        assert.equal(20, game:write_legal_moves(moves))
        assert.equal(2, game:write_legal_moves(moves, JustChess.Square.E2))
        for index = 1, 2 do
            assert.equal(JustChess.Square.E2, JustChess.Move.from_square(moves[index]))
        end
    end)

    it("finds checks applies and undoes moves", function()
        local game = JustChess.new_game()
        local original = Internal.Position.clone(game._position)
        local move = assert(game:find_legal_move(JustChess.Square.E2, JustChess.Square.E4))

        game:make_move_unchecked(move)
        assert.equal(JustChess.Color.BLACK, game:side_to_move())
        assert.equal(JustChess.Piece.WHITE_PAWN, game:piece_at(JustChess.Square.E4))
        assert.is_nil(game:piece_at(JustChess.Square.E2))
        assert.equal(1, game:move_count())
        assert.equal(move, game:move_at(1))

        assert.equal(move, game:undo_move())
        assert.equal(0, game:move_count())
        assert.is_nil(game:undo_move())
        assert.same(original, game._position)
    end)

    it("checks GUI move requests without changing the position on failure", function()
        local game = JustChess.new_game()
        local original = Internal.Position.clone(game._position)

        local ok, move_error = game:try_make_move(JustChess.Square.E2, JustChess.Square.E5)
        assert.is_nil(ok)
        assert.equal("move is not legal", move_error)

        ok, move_error = game:try_make_move(0, JustChess.Square.E4)
        assert.is_nil(ok)
        assert.equal("invalid source square", move_error)
        assert.same(original, game._position)

        assert.is_true(game:try_make_move(JustChess.Square.E2, JustChess.Square.E4))
    end)

    it("requires an explicit promotion choice", function()
        local position = fen.parse("4k3/6P1/8/8/8/8/8/4K3 w - - 0 1", namespace)
        local game = Internal.Game.new(position)

        local move, move_error = game:find_legal_move(JustChess.Square.G7, JustChess.Square.G8)
        assert.is_nil(move)
        assert.equal("promotion is required", move_error)

        move = assert(game:find_legal_move(JustChess.Square.G7, JustChess.Square.G8, JustChess.Promotion.KNIGHT))
        assert.equal(JustChess.Promotion.KNIGHT, JustChess.Move.promotion(move))
        assert.is_true(game:try_make_move(JustChess.Square.G7, JustChess.Square.G8, JustChess.Promotion.QUEEN))
        assert.equal(JustChess.Piece.WHITE_QUEEN, game:piece_at(JustChess.Square.G8))
    end)

    it("reports check checkmate and stalemate", function()
        local cases = {
            { "7k/8/8/8/8/8/6r1/6K1 w - - 0 1", "check" },
            { "7k/6Q1/6K1/8/8/8/8/8 b - - 0 1", "checkmate" },
            { "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1", "stalemate" },
        }

        for index = 1, #cases do
            local game = Internal.Game.new(fen.parse(cases[index][1], namespace))
            assert.equal(cases[index][2], game:status())
            assert.equal(cases[index][2] ~= "stalemate", game:is_in_check())
        end
    end)

    it("resets position and history", function()
        local game = JustChess.new_game()
        local position = game._position
        assert.is_true(game:try_make_move(JustChess.Square.E2, JustChess.Square.E4))

        game:reset()

        assert.equal(position, game._position)
        assert.equal(0, game:move_count())
        assert.equal(JustChess.Color.WHITE, game:side_to_move())
        assert.equal(JustChess.Piece.WHITE_PAWN, game:piece_at(JustChess.Square.E2))
        assert.equal(20, #game:get_legal_moves())
    end)

    it("allocates no garbage when writing warmed legal moves", function()
        local game = JustChess.new_game()
        local moves = {}
        for _ = 1, 100 do
            game:write_legal_moves(moves)
        end

        collectgarbage("collect")
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 1000 do
            game:write_legal_moves(moves)
        end
        local after = collectgarbage("count")
        collectgarbage("restart")
        assert.equal(before, after)
    end)
end)
