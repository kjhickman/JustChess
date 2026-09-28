local loader = require("spec.support.load_just_chess")

describe("constants", function()
    local JustChess
    local Internal

    before_each(function()
        local namespace = loader.load()
        JustChess = namespace.JustChess
        Internal = namespace.JustChessInternal
    end)

    it("exposes colors and their opposites", function()
        assert.equal(1, JustChess.Color.WHITE)
        assert.equal(2, JustChess.Color.BLACK)
        assert.equal(JustChess.Color.BLACK, JustChess.Color.opposite(JustChess.Color.WHITE))
        assert.equal(JustChess.Color.WHITE, JustChess.Color.opposite(JustChess.Color.BLACK))
        assert.has_error(function()
            JustChess.Color.opposite(3)
        end, "invalid color")
    end)

    it("exposes only concrete pieces", function()
        local expected = {
            BLACK_BISHOP = 9,
            BLACK_KING = 12,
            BLACK_KNIGHT = 8,
            BLACK_PAWN = 7,
            BLACK_QUEEN = 11,
            BLACK_ROOK = 10,
            WHITE_BISHOP = 3,
            WHITE_KING = 6,
            WHITE_KNIGHT = 2,
            WHITE_PAWN = 1,
            WHITE_QUEEN = 5,
            WHITE_ROOK = 4,
        }

        assert.same(expected, JustChess.Piece)
    end)

    it("exposes only promotion choices", function()
        assert.same({
            BISHOP = 2,
            KNIGHT = 1,
            QUEEN = 8,
            ROOK = 4,
        }, JustChess.Promotion)
    end)

    it("keeps rule representation private", function()
        assert.is_nil(JustChess.PieceKind)
        assert.is_nil(JustChess.SpecialMove)
        assert.is_nil(JustChess.CastlingRights)

        for kind = Internal.PieceKind.PAWN, Internal.PieceKind.KING do
            local white_piece = Internal.Piece.from_color_kind(Internal.Color.WHITE, kind)
            local black_piece = Internal.Piece.from_color_kind(Internal.Color.BLACK, kind)

            assert.equal(kind, white_piece)
            assert.equal(kind + 6, black_piece)
            assert.equal(Internal.Color.WHITE, Internal.Piece.color(white_piece))
            assert.equal(Internal.Color.BLACK, Internal.Piece.color(black_piece))
            assert.equal(kind, Internal.Piece.kind(white_piece))
            assert.equal(kind, Internal.Piece.kind(black_piece))
        end

        assert.equal(0, Internal.Piece.NONE)
        assert.equal(0, Internal.Promotion.NONE)
        assert.equal(15, Internal.CastlingRights.ALL)
        assert.equal(1, Internal.SpecialMove.DOUBLE_PAWN_PUSH)
        assert.equal(2, Internal.SpecialMove.EN_PASSANT)
        assert.equal(3, Internal.SpecialMove.SHORT_CASTLE)
        assert.equal(4, Internal.SpecialMove.LONG_CASTLE)
    end)
end)
