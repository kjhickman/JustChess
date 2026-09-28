local loader = require("spec.support.load_just_chess")

describe("packed moves", function()
    local JustChess
    local Internal
    local Move
    local PackedMove
    local Piece
    local Promotion
    local SpecialMove

    before_each(function()
        local namespace = loader.load()
        JustChess = namespace.JustChess
        Internal = namespace.JustChessInternal
        Move = JustChess.Move
        PackedMove = Internal.Move
        Piece = Internal.Piece
        Promotion = Internal.Promotion
        SpecialMove = Internal.SpecialMove
    end)

    local function assert_move(move, from, to, promotion, piece, captured, capture, special)
        assert.equal(from, PackedMove.from_square(move))
        assert.equal(to, PackedMove.to_square(move))
        assert.equal(promotion, PackedMove.promotion(move))
        assert.equal(piece, PackedMove.piece(move))
        assert.equal(captured, PackedMove.captured_piece(move))
        assert.equal(capture, PackedMove.is_capture(move))
        assert.equal(special, PackedMove.special_type(move))

        assert.equal(to, Move.to_square(move))
        assert.equal(promotion ~= Promotion.NONE and promotion or nil, Move.promotion(move))
        assert.equal(capture, Move.is_capture(move))
    end

    it("exposes only UI move details", function()
        assert.is_function(Move.to_square)
        assert.is_function(Move.promotion)
        assert.is_function(Move.is_capture)
        assert.is_nil(Move.from_square)
        assert.is_nil(Move.piece)
        assert.is_nil(Move.captured_piece)
        assert.is_nil(Move.special_type)
    end)

    it("round trips every source and destination square", function()
        for from = 1, 64 do
            for to = 1, 64 do
                local move = PackedMove.pack(
                    from,
                    to,
                    Promotion.QUEEN,
                    Piece.WHITE_PAWN,
                    Piece.BLACK_ROOK,
                    SpecialMove.EN_PASSANT
                )
                assert_move(
                    move,
                    from,
                    to,
                    Promotion.QUEEN,
                    Piece.WHITE_PAWN,
                    Piece.BLACK_ROOK,
                    true,
                    SpecialMove.EN_PASSANT
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
                            captured ~= Piece.NONE,
                            special
                        )
                    end
                end
            end
        end
    end)

    it("constructs ordinary and promotion moves", function()
        assert_move(
            PackedMove.quiet(JustChess.Square.E2, JustChess.Square.E3, Piece.WHITE_PAWN),
            JustChess.Square.E2,
            JustChess.Square.E3,
            Promotion.NONE,
            Piece.WHITE_PAWN,
            Piece.NONE,
            false,
            SpecialMove.NONE
        )
        assert_move(
            PackedMove.capture(JustChess.Square.C4, JustChess.Square.D5, Piece.WHITE_BISHOP, Piece.BLACK_KNIGHT),
            JustChess.Square.C4,
            JustChess.Square.D5,
            Promotion.NONE,
            Piece.WHITE_BISHOP,
            Piece.BLACK_KNIGHT,
            true,
            SpecialMove.NONE
        )
        assert_move(
            PackedMove.promote_capture(
                JustChess.Square.G7,
                JustChess.Square.H8,
                Piece.WHITE_PAWN,
                Piece.BLACK_ROOK,
                Promotion.QUEEN
            ),
            JustChess.Square.G7,
            JustChess.Square.H8,
            Promotion.QUEEN,
            Piece.WHITE_PAWN,
            Piece.BLACK_ROOK,
            true,
            SpecialMove.NONE
        )
    end)

    it("constructs every special move", function()
        local white_en_passant = PackedMove.en_passant(JustChess.Square.E5, JustChess.Square.D6, Internal.Color.WHITE)
        assert.equal(Piece.WHITE_PAWN, PackedMove.piece(white_en_passant))
        assert.equal(Piece.BLACK_PAWN, PackedMove.captured_piece(white_en_passant))
        assert.is_true(Move.is_capture(white_en_passant))
        assert.equal(SpecialMove.EN_PASSANT, PackedMove.special_type(white_en_passant))

        local black_en_passant = PackedMove.en_passant(JustChess.Square.E4, JustChess.Square.D3, Internal.Color.BLACK)
        assert.equal(Piece.BLACK_PAWN, PackedMove.piece(black_en_passant))
        assert.equal(Piece.WHITE_PAWN, PackedMove.captured_piece(black_en_passant))

        local white_short = PackedMove.short_castle(Internal.Color.WHITE)
        assert.equal(JustChess.Square.E1, PackedMove.from_square(white_short))
        assert.equal(JustChess.Square.G1, Move.to_square(white_short))
        assert.equal(SpecialMove.SHORT_CASTLE, PackedMove.special_type(white_short))

        local black_long = PackedMove.long_castle(Internal.Color.BLACK)
        assert.equal(JustChess.Square.E8, PackedMove.from_square(black_long))
        assert.equal(JustChess.Square.C8, Move.to_square(black_long))
        assert.equal(SpecialMove.LONG_CASTLE, PackedMove.special_type(black_long))

        local double_push = PackedMove.double_pawn_push(JustChess.Square.A2, JustChess.Square.A4, Piece.WHITE_PAWN)
        assert.equal(SpecialMove.DOUBLE_PAWN_PUSH, PackedMove.special_type(double_push))
    end)
end)
