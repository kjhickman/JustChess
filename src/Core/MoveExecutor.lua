local _, addon = ...

local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local CastlingRights = assert(Internal.CastlingRights, "JustChess constants must load first")
local Color = assert(Internal.Color, "JustChess constants must load first")
local Piece = assert(Internal.Piece, "JustChess constants must load first")
local PieceKind = assert(Internal.PieceKind, "JustChess constants must load first")
local Position = assert(Internal.Position, "JustChess position must load first")
local Promotion = assert(Internal.Promotion, "JustChess constants must load first")
local SpecialMove = assert(Internal.SpecialMove, "JustChess constants must load first")
local Square = assert(Internal.Square, "JustChess constants must load first")
local band = bit.band
local bnot = bit.bnot
local floor = math.floor

local MoveExecutor = {}

local promotion_kind = {
    [Promotion.KNIGHT] = PieceKind.KNIGHT,
    [Promotion.BISHOP] = PieceKind.BISHOP,
    [Promotion.ROOK] = PieceKind.ROOK,
    [Promotion.QUEEN] = PieceKind.QUEEN,
}

local function remove_rights(position, rights)
    position.castling_rights = band(position.castling_rights, bnot(rights))
end

local function promoted_piece(moving_piece, promotion)
    return Piece.from_color_kind(Internal.piece_color[moving_piece], promotion_kind[promotion])
end

local function update_castling_rights(position, from, to, piece, captured, is_capture)
    if piece == Piece.WHITE_KING then
        remove_rights(position, CastlingRights.WHITE_KINGSIDE + CastlingRights.WHITE_QUEENSIDE)
    elseif piece == Piece.BLACK_KING then
        remove_rights(position, CastlingRights.BLACK_KINGSIDE + CastlingRights.BLACK_QUEENSIDE)
    elseif piece == Piece.WHITE_ROOK then
        if from == Square.H1 then
            remove_rights(position, CastlingRights.WHITE_KINGSIDE)
        elseif from == Square.A1 then
            remove_rights(position, CastlingRights.WHITE_QUEENSIDE)
        end
    elseif piece == Piece.BLACK_ROOK then
        if from == Square.H8 then
            remove_rights(position, CastlingRights.BLACK_KINGSIDE)
        elseif from == Square.A8 then
            remove_rights(position, CastlingRights.BLACK_QUEENSIDE)
        end
    end

    if not is_capture then
        return
    end

    if captured == Piece.WHITE_ROOK then
        if to == Square.H1 then
            remove_rights(position, CastlingRights.WHITE_KINGSIDE)
        elseif to == Square.A1 then
            remove_rights(position, CastlingRights.WHITE_QUEENSIDE)
        end
    elseif captured == Piece.BLACK_ROOK then
        if to == Square.H8 then
            remove_rights(position, CastlingRights.BLACK_KINGSIDE)
        elseif to == Square.A8 then
            remove_rights(position, CastlingRights.BLACK_QUEENSIDE)
        end
    end
end

local function move_castle(position, king_from, king_to, king, undo)
    local kingside = king_to > king_from
    local rook_from = kingside and king_to + 1 or king_to - 2
    local rook_to = kingside and king_to - 1 or king_to + 1
    if undo then
        king_from, king_to = king_to, king_from
        rook_from, rook_to = rook_to, rook_from
    end

    local rook = king == Piece.WHITE_KING and Piece.WHITE_ROOK or Piece.BLACK_ROOK
    Position.move_piece(position, king_from, king_to, king)
    Position.move_piece(position, rook_from, rook_to, rook)
end

function MoveExecutor.new()
    return {
        history = {},
        count = 0,
    }
end

function MoveExecutor.make(executor, position, move)
    local next_index = executor.count + 1
    local record = executor.history[next_index]
    if record == nil then
        record = {}
        executor.history[next_index] = record
    end

    record.move = move
    record.castling_rights = position.castling_rights
    record.en_passant_target = position.en_passant_target
    record.halfmove_clock = position.halfmove_clock
    record.fullmove_number = position.fullmove_number
    executor.count = next_index

    local from = move % 64 + 1
    local to = floor(move / 64) % 64 + 1
    local promotion = floor(move / 4096) % 16
    local piece = floor(move / 65536) % 16
    local captured = floor(move / 1048576) % 16
    local is_capture = captured ~= Piece.NONE
    local special = floor(move / 16777216) % 8
    local color = Internal.piece_color[piece]

    position.en_passant_target = nil

    if special == SpecialMove.SHORT_CASTLE or special == SpecialMove.LONG_CASTLE then
        move_castle(position, from, to, piece, false)
    elseif special == SpecialMove.EN_PASSANT then
        Position.move_piece(position, from, to, piece)
        local captured_square = color == Color.WHITE and to - 8 or to + 8
        Position.remove_piece(position, captured_square, captured)
    elseif promotion ~= Promotion.NONE then
        if is_capture then
            Position.remove_piece(position, to, captured)
        end
        Position.remove_piece(position, from, piece)
        Position.add_piece(position, to, promoted_piece(piece, promotion))
    else
        if is_capture then
            Position.remove_piece(position, to, captured)
        end
        Position.move_piece(position, from, to, piece)
        if special == SpecialMove.DOUBLE_PAWN_PUSH then
            position.en_passant_target = color == Color.WHITE and to - 8 or to + 8
        end
    end

    update_castling_rights(position, from, to, piece, captured, is_capture)

    if Internal.piece_kind[piece] == PieceKind.PAWN or is_capture then
        position.halfmove_clock = 0
    else
        position.halfmove_clock = position.halfmove_clock + 1
    end

    if position.side_to_move == Color.BLACK then
        position.fullmove_number = position.fullmove_number + 1
    end
    position.side_to_move = Color.opposite(position.side_to_move)
end

function MoveExecutor.undo(executor, position)
    if executor.count == 0 then
        return nil
    end

    local record = executor.history[executor.count]
    local move = record.move
    executor.count = executor.count - 1

    local from = move % 64 + 1
    local to = floor(move / 64) % 64 + 1
    local promotion = floor(move / 4096) % 16
    local piece = floor(move / 65536) % 16
    local captured = floor(move / 1048576) % 16
    local is_capture = captured ~= Piece.NONE
    local special = floor(move / 16777216) % 8
    local color = Internal.piece_color[piece]

    if special == SpecialMove.SHORT_CASTLE or special == SpecialMove.LONG_CASTLE then
        move_castle(position, from, to, piece, true)
    elseif special == SpecialMove.EN_PASSANT then
        Position.move_piece(position, to, from, piece)
        local captured_square = color == Color.WHITE and to - 8 or to + 8
        Position.add_piece(position, captured_square, captured)
    elseif promotion ~= Promotion.NONE then
        Position.remove_piece(position, to, promoted_piece(piece, promotion))
        Position.add_piece(position, from, piece)
        if is_capture then
            Position.add_piece(position, to, captured)
        end
    else
        Position.move_piece(position, to, from, piece)
        if is_capture then
            Position.add_piece(position, to, captured)
        end
    end

    position.side_to_move = color
    position.castling_rights = record.castling_rights
    position.en_passant_target = record.en_passant_target
    position.halfmove_clock = record.halfmove_clock
    position.fullmove_number = record.fullmove_number
    return move
end

Internal.MoveExecutor = MoveExecutor
