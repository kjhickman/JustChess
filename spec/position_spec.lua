local loader = require("spec.support.load_just_chess")
local position_assertions = require("spec.support.position_assertions")

describe("positions", function()
    local JustChess
    local Internal
    local Position

    before_each(function()
        local namespace = loader.load()
        JustChess = namespace.JustChess
        Internal = namespace.JustChessInternal
        Position = Internal.Position
    end)

    it("creates the standard starting position", function()
        local position = Position.new()
        local Piece = JustChess.Piece
        local Square = JustChess.Square

        assert.equal(32, Internal.Bitboard.count(position.occupied))
        assert.equal(Piece.WHITE_ROOK, Position.piece_at(position, Square.A1))
        assert.equal(Piece.WHITE_KING, Position.piece_at(position, Square.E1))
        assert.equal(Piece.WHITE_PAWN, Position.piece_at(position, Square.H2))
        assert.is_nil(Position.piece_at(position, Square.E4))
        assert.equal(Piece.BLACK_PAWN, Position.piece_at(position, Square.A7))
        assert.equal(Piece.BLACK_KING, Position.piece_at(position, Square.E8))
        assert.equal(Piece.BLACK_ROOK, Position.piece_at(position, Square.H8))
        assert.equal(JustChess.Color.WHITE, position.side_to_move)
        assert.equal(Internal.CastlingRights.ALL, position.castling_rights)
        assert.is_nil(position.en_passant_target)
        assert.equal(0, position.halfmove_clock)
        assert.equal(1, position.fullmove_number)
        position_assertions.assert_consistent(position, JustChess, Internal)
    end)

    it("sets and replaces pieces while preserving derived state", function()
        local position = Position.new_empty()
        local Square = JustChess.Square

        Position.set_piece(position, Square.E1, JustChess.Piece.WHITE_KING)
        Position.set_piece(position, Square.E8, JustChess.Piece.BLACK_KING)
        Position.set_piece(position, Square.A1, JustChess.Piece.WHITE_ROOK)
        Position.set_piece(position, Square.A1, JustChess.Piece.BLACK_QUEEN)
        Position.set_piece(position, Square.A1, Internal.Piece.NONE)

        assert.is_nil(position.board[Square.A1])
        assert.equal(Square.E1, position.king_square[JustChess.Color.WHITE])
        assert.equal(Square.E8, position.king_square[JustChess.Color.BLACK])
        assert.equal(2, Internal.Bitboard.count(position.occupied))
        position_assertions.assert_consistent(position, JustChess, Internal)
    end)

    it("clones without sharing mutable state", function()
        local position = Position.new()
        position.side_to_move = JustChess.Color.BLACK
        position.en_passant_target = JustChess.Square.E3
        position.halfmove_clock = 7
        position.fullmove_number = 12
        local clone = Position.clone(position)

        assert.same(position, clone)
        Position.set_piece(clone, JustChess.Square.A2, Internal.Piece.NONE)
        assert.equal(32, Internal.Bitboard.count(position.occupied))
        assert.equal(31, Internal.Bitboard.count(clone.occupied))
    end)

    it("resets an existing position without replacing its bitboards", function()
        local position = Position.new_empty()
        local occupied = position.occupied
        local white_pawns = position.pieces[JustChess.Piece.WHITE_PAWN]
        Position.set_piece(position, JustChess.Square.E4, JustChess.Piece.BLACK_QUEEN)

        Position.reset(position)

        assert.equal(occupied, position.occupied)
        assert.equal(white_pawns, position.pieces[JustChess.Piece.WHITE_PAWN])
        assert.equal(32, Internal.Bitboard.count(position.occupied))
        position_assertions.assert_consistent(position, JustChess, Internal)
    end)
end)
