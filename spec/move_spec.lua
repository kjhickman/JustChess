local loader = require("spec.support.load_just_chess")

describe("packed moves", function()
    local JustChess
    local Move
    local PackedMove

    before_each(function()
        local namespace = loader.load()
        JustChess = namespace.JustChess
        Move = JustChess.Move
        PackedMove = namespace.JustChessInternal.Move
    end)

    local function assert_move(move, from, to, promotion, piece, captured, capture, special)
        assert.equal(from, Move.from_square(move))
        assert.equal(to, Move.to_square(move))
        assert.equal(promotion, Move.promotion(move))
        assert.equal(piece, Move.piece(move))
        assert.equal(captured, Move.captured_piece(move))
        assert.equal(capture, Move.is_capture(move))
        assert.equal(special, Move.special_type(move))
    end

    it("round trips every source and destination square", function()
        for from = 1, 64 do
            for to = 1, 64 do
                local move = PackedMove.pack(
                    from,
                    to,
                    JustChess.Promotion.QUEEN,
                    JustChess.Piece.WHITE_PAWN,
                    JustChess.Piece.BLACK_ROOK,
                    JustChess.SpecialMove.EN_PASSANT
                )
                assert_move(
                    move,
                    from,
                    to,
                    JustChess.Promotion.QUEEN,
                    JustChess.Piece.WHITE_PAWN,
                    JustChess.Piece.BLACK_ROOK,
                    true,
                    JustChess.SpecialMove.EN_PASSANT
                )
            end
        end
    end)

    it("round trips every metadata value", function()
        local promotions = { 0, 1, 2, 4, 8 }
        for promotion_index = 1, #promotions do
            for piece = 1, 12 do
                for captured = 0, 12 do
                    for special = 0, 4 do
                        local move = PackedMove.pack(1, 64, promotions[promotion_index], piece, captured, special)
                        assert_move(
                            move,
                            1,
                            64,
                            promotions[promotion_index],
                            piece,
                            captured,
                            captured ~= JustChess.Piece.NONE,
                            special
                        )
                    end
                end
            end
        end
    end)

    it("constructs ordinary and promotion moves", function()
        assert_move(
            PackedMove.quiet(JustChess.Square.E2, JustChess.Square.E3, JustChess.Piece.WHITE_PAWN),
            JustChess.Square.E2,
            JustChess.Square.E3,
            JustChess.Promotion.NONE,
            JustChess.Piece.WHITE_PAWN,
            JustChess.Piece.NONE,
            false,
            JustChess.SpecialMove.NONE
        )
        assert_move(
            PackedMove.capture(
                JustChess.Square.C4,
                JustChess.Square.D5,
                JustChess.Piece.WHITE_BISHOP,
                JustChess.Piece.BLACK_KNIGHT
            ),
            JustChess.Square.C4,
            JustChess.Square.D5,
            JustChess.Promotion.NONE,
            JustChess.Piece.WHITE_BISHOP,
            JustChess.Piece.BLACK_KNIGHT,
            true,
            JustChess.SpecialMove.NONE
        )
        assert_move(
            PackedMove.promote_capture(
                JustChess.Square.G7,
                JustChess.Square.H8,
                JustChess.Piece.WHITE_PAWN,
                JustChess.Piece.BLACK_ROOK,
                JustChess.Promotion.QUEEN
            ),
            JustChess.Square.G7,
            JustChess.Square.H8,
            JustChess.Promotion.QUEEN,
            JustChess.Piece.WHITE_PAWN,
            JustChess.Piece.BLACK_ROOK,
            true,
            JustChess.SpecialMove.NONE
        )
    end)

    it("constructs every special move", function()
        local white_en_passant = PackedMove.en_passant(JustChess.Square.E5, JustChess.Square.D6, JustChess.Color.WHITE)
        assert.equal(JustChess.Piece.WHITE_PAWN, Move.piece(white_en_passant))
        assert.equal(JustChess.Piece.BLACK_PAWN, Move.captured_piece(white_en_passant))
        assert.is_true(Move.is_capture(white_en_passant))
        assert.equal(JustChess.SpecialMove.EN_PASSANT, Move.special_type(white_en_passant))

        local black_en_passant = PackedMove.en_passant(JustChess.Square.E4, JustChess.Square.D3, JustChess.Color.BLACK)
        assert.equal(JustChess.Piece.BLACK_PAWN, Move.piece(black_en_passant))
        assert.equal(JustChess.Piece.WHITE_PAWN, Move.captured_piece(black_en_passant))

        local white_short = PackedMove.short_castle(JustChess.Color.WHITE)
        assert.equal(JustChess.Square.E1, Move.from_square(white_short))
        assert.equal(JustChess.Square.G1, Move.to_square(white_short))
        assert.equal(JustChess.SpecialMove.SHORT_CASTLE, Move.special_type(white_short))

        local black_long = PackedMove.long_castle(JustChess.Color.BLACK)
        assert.equal(JustChess.Square.E8, Move.from_square(black_long))
        assert.equal(JustChess.Square.C8, Move.to_square(black_long))
        assert.equal(JustChess.SpecialMove.LONG_CASTLE, Move.special_type(black_long))

        local double_push =
            PackedMove.double_pawn_push(JustChess.Square.A2, JustChess.Square.A4, JustChess.Piece.WHITE_PAWN)
        assert.equal(JustChess.SpecialMove.DOUBLE_PAWN_PUSH, Move.special_type(double_push))
    end)
end)
