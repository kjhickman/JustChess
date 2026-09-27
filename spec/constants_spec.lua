local loader = require("spec.support.load_just_chess")

describe("constants", function()
    local JustChess

    before_each(function()
        JustChess = loader.load().JustChess
    end)

    it("defines colors and their opposites", function()
        assert.equal(1, JustChess.Color.WHITE)
        assert.equal(2, JustChess.Color.BLACK)
        assert.equal(JustChess.Color.BLACK, JustChess.Color.opposite(JustChess.Color.WHITE))
        assert.equal(JustChess.Color.WHITE, JustChess.Color.opposite(JustChess.Color.BLACK))
        assert.has_error(function()
            JustChess.Color.opposite(3)
        end, "invalid color")
    end)

    it("defines color-specific pieces in contiguous groups", function()
        for kind = JustChess.PieceKind.PAWN, JustChess.PieceKind.KING do
            local white_piece = JustChess.Piece.from_color_kind(JustChess.Color.WHITE, kind)
            local black_piece = JustChess.Piece.from_color_kind(JustChess.Color.BLACK, kind)

            assert.equal(kind, white_piece)
            assert.equal(kind + 6, black_piece)
            assert.equal(JustChess.Color.WHITE, JustChess.Piece.color(white_piece))
            assert.equal(JustChess.Color.BLACK, JustChess.Piece.color(black_piece))
            assert.equal(kind, JustChess.Piece.kind(white_piece))
            assert.equal(kind, JustChess.Piece.kind(black_piece))
        end

        assert.is_nil(JustChess.Piece.color(JustChess.Piece.NONE))
        assert.is_nil(JustChess.Piece.kind(JustChess.Piece.NONE))
    end)

    it("defines packed promotion and state flags", function()
        assert.same({ 0, 1, 2, 4, 8 }, {
            JustChess.Promotion.NONE,
            JustChess.Promotion.KNIGHT,
            JustChess.Promotion.BISHOP,
            JustChess.Promotion.ROOK,
            JustChess.Promotion.QUEEN,
        })
        assert.equal(15, JustChess.CastlingRights.ALL)
        assert.equal(1, JustChess.SpecialMove.DOUBLE_PAWN_PUSH)
        assert.equal(2, JustChess.SpecialMove.EN_PASSANT)
        assert.equal(3, JustChess.SpecialMove.SHORT_CASTLE)
        assert.equal(4, JustChess.SpecialMove.LONG_CASTLE)
    end)
end)
