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

    it("creates a standard game and answers UI queries", function()
        local game = JustChess.new_game()

        assert.equal(JustChess.Color.WHITE, game:side_to_move())
        assert.equal(JustChess.Piece.WHITE_KING, game:piece_at(JustChess.Square.E1))
        assert.equal(JustChess.Piece.BLACK_PAWN, game:piece_at(JustChess.Square.A7))
        assert.is_nil(game:piece_at(JustChess.Square.E4))
        assert.equal("ongoing", game:status())

        local moves = game:get_legal_moves(JustChess.Square.E2)
        assert.equal(2, #moves)
        assert.same({
            [JustChess.Square.E3] = true,
            [JustChess.Square.E4] = true,
        }, {
            [JustChess.Move.to_square(moves[1])] = true,
            [JustChess.Move.to_square(moves[2])] = true,
        })
    end)

    it("exposes only the gameplay surface", function()
        local game = JustChess.new_game()

        assert.is_function(game.piece_at)
        assert.is_function(game.side_to_move)
        assert.is_function(game.get_legal_moves)
        assert.is_function(game.try_make_move)
        assert.is_function(game.status)
        assert.is_function(game.undo_move)
        assert.is_nil(game.write_legal_moves)
        assert.is_nil(game.find_legal_move)
        assert.is_nil(game.make_move_unchecked)
        assert.is_nil(game.reset)
        assert.is_nil(game.is_in_check)
        assert.is_nil(game.move_count)
        assert.is_nil(game.move_at)
        assert.is_nil(game.new)
    end)

    it("applies and undoes legal moves", function()
        local game = JustChess.new_game()
        local original = Internal.Position.clone(game._position)

        assert.is_true(game:try_make_move(JustChess.Square.E2, JustChess.Square.E4))
        assert.equal(JustChess.Color.BLACK, game:side_to_move())
        assert.equal(JustChess.Piece.WHITE_PAWN, game:piece_at(JustChess.Square.E4))
        assert.is_nil(game:piece_at(JustChess.Square.E2))

        assert.is_true(game:undo_move())
        assert.is_nil(game:undo_move())
        assert.same(original, game._position)
    end)

    it("rejects invalid move requests without changing the position", function()
        local game = JustChess.new_game()
        local original = Internal.Position.clone(game._position)

        local ok, move_error = game:try_make_move(JustChess.Square.E2, JustChess.Square.E5)
        assert.is_nil(ok)
        assert.equal("move is not legal", move_error)

        ok, move_error = game:try_make_move(0, JustChess.Square.E4)
        assert.is_nil(ok)
        assert.equal("invalid source square", move_error)
        assert.same(original, game._position)
        assert.has_error(function()
            game:get_legal_moves()
        end, "invalid source square")
    end)

    it("requires an explicit promotion choice", function()
        local position = fen.parse("4k3/6P1/8/8/8/8/8/4K3 w - - 0 1", namespace)
        local game = Internal.Game.new(position)
        local moves = game:get_legal_moves(JustChess.Square.G7)
        local promotions = {}

        assert.equal(4, #moves)
        for index = 1, #moves do
            assert.equal(JustChess.Square.G8, JustChess.Move.to_square(moves[index]))
            promotions[JustChess.Move.promotion(moves[index])] = true
        end
        assert.same({
            [JustChess.Promotion.KNIGHT] = true,
            [JustChess.Promotion.BISHOP] = true,
            [JustChess.Promotion.ROOK] = true,
            [JustChess.Promotion.QUEEN] = true,
        }, promotions)

        local ok, move_error = game:try_make_move(JustChess.Square.G7, JustChess.Square.G8)
        assert.is_nil(ok)
        assert.equal("promotion is required", move_error)
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
        end
    end)
end)
