local M = {}

local piece_by_character_name = {
    P = "WHITE_PAWN",
    N = "WHITE_KNIGHT",
    B = "WHITE_BISHOP",
    R = "WHITE_ROOK",
    Q = "WHITE_QUEEN",
    K = "WHITE_KING",
    p = "BLACK_PAWN",
    n = "BLACK_KNIGHT",
    b = "BLACK_BISHOP",
    r = "BLACK_ROOK",
    q = "BLACK_QUEEN",
    k = "BLACK_KING",
}

function M.parse(fen, namespace)
    local fields = {}
    for field in fen:gmatch("%S+") do
        fields[#fields + 1] = field
    end
    assert(#fields == 6, "FEN must contain six fields")

    local JustChess = namespace.JustChess
    local Internal = namespace.JustChessInternal
    local Position = Internal.Position
    local position = Position.new_empty()
    local rank = 8
    local file = 1

    for index = 1, #fields[1] do
        local character = fields[1]:sub(index, index)
        if character == "/" then
            assert(file == 9, "FEN rank must contain eight squares")
            rank = rank - 1
            file = 1
        else
            local empty_count = tonumber(character)
            if empty_count ~= nil then
                file = file + empty_count
            else
                local piece_name = piece_by_character_name[character]
                assert(piece_name ~= nil, "invalid FEN piece")
                Position.set_piece(position, JustChess.Square.from_rank_file(rank, file), JustChess.Piece[piece_name])
                file = file + 1
            end
        end
    end
    assert(rank == 1 and file == 9, "FEN board must contain eight ranks")

    if fields[2] == "w" then
        position.side_to_move = JustChess.Color.WHITE
    elseif fields[2] == "b" then
        position.side_to_move = JustChess.Color.BLACK
    else
        error("invalid FEN side to move")
    end

    local rights = 0
    if fields[3] ~= "-" then
        if fields[3]:find("K", 1, true) then
            rights = rights + Internal.CastlingRights.WHITE_KINGSIDE
        end
        if fields[3]:find("Q", 1, true) then
            rights = rights + Internal.CastlingRights.WHITE_QUEENSIDE
        end
        if fields[3]:find("k", 1, true) then
            rights = rights + Internal.CastlingRights.BLACK_KINGSIDE
        end
        if fields[3]:find("q", 1, true) then
            rights = rights + Internal.CastlingRights.BLACK_QUEENSIDE
        end
    end
    position.castling_rights = rights

    if fields[4] ~= "-" then
        position.en_passant_target = assert(JustChess.Square.from_name(fields[4]), "invalid FEN en passant target")
    end
    position.halfmove_clock = assert(tonumber(fields[5]), "invalid FEN halfmove clock")
    position.fullmove_number = assert(tonumber(fields[6]), "invalid FEN fullmove number")
    return position
end

return M
