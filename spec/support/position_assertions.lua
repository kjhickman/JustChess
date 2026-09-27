local M = {}

local function assert_equal(expected, actual, label)
    assert(
        expected == actual,
        (label or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
    )
end

local function assert_bitboard_equal(expected, actual, label)
    assert(expected.lo == actual.lo and expected.hi == actual.hi, label)
end

function M.assert_consistent(position, JustChess, Internal)
    local Bitboard = Internal.Bitboard
    local Color = JustChess.Color
    local Piece = JustChess.Piece
    local expected_occupied = Bitboard.new()
    local expected_king_square = {}

    for square = 1, 64 do
        local board_piece = position.board[square]
        local bitboard_piece
        for piece = Piece.WHITE_PAWN, Piece.BLACK_KING do
            if Bitboard.contains(position.pieces[piece], square) then
                assert(bitboard_piece == nil, "multiple piece bitboards contain square " .. square)
                bitboard_piece = piece
            end
        end

        assert_equal(board_piece, bitboard_piece, "mailbox mismatch on square " .. square)
        if board_piece ~= nil then
            Bitboard.set(expected_occupied, square)
            if board_piece == Piece.WHITE_KING then
                expected_king_square[Color.WHITE] = square
            elseif board_piece == Piece.BLACK_KING then
                expected_king_square[Color.BLACK] = square
            end
        end
    end

    assert_bitboard_equal(expected_occupied, position.occupied, "combined occupancy mismatch")
    assert_equal(expected_king_square[Color.WHITE], position.king_square[Color.WHITE], "white king square")
    assert_equal(expected_king_square[Color.BLACK], position.king_square[Color.BLACK], "black king square")
end

return M
