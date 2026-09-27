local _, addon = ...

local JustChess = assert(addon.JustChess, "JustChess bootstrap must load first")
local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local Attacks = assert(Internal.Attacks, "JustChess attacks must load first")
local AttackTables = assert(Internal.AttackTables, "JustChess attack tables must load first")
local Bitboard = assert(Internal.Bitboard, "JustChess bitboard must load first")
local CastlingRights = assert(JustChess.CastlingRights, "JustChess constants must load first")
local Color = assert(JustChess.Color, "JustChess constants must load first")
local Move = assert(Internal.Move, "JustChess move must load first")
local Piece = assert(JustChess.Piece, "JustChess constants must load first")
local PieceKind = assert(JustChess.PieceKind, "JustChess constants must load first")
local Promotion = assert(JustChess.Promotion, "JustChess constants must load first")
local SpecialMove = assert(JustChess.SpecialMove, "JustChess constants must load first")
local Square = assert(JustChess.Square, "JustChess constants must load first")
local abs = math.abs
local band = bit.band
local bnot = bit.bnot
local bor = bit.bor
local floor = math.floor

local MoveGeneration = {}

local mask_lo = Bitboard.square_mask_lo
local mask_hi = Bitboard.square_mask_hi
local lsb_index = Bitboard.lsb_index

local function append_target_moves(output, count, position, color, from, moving_piece, targets_lo, targets_hi)
    while targets_lo ~= 0 do
        local isolated = band(targets_lo, -targets_lo)
        local to = lsb_index[isolated] + 1
        local captured = position.board[to]
        if captured == nil then
            count = count + 1
            output[count] = Move.quiet(from, to, moving_piece)
        elseif Internal.piece_color[captured] ~= color and Internal.piece_kind[captured] ~= PieceKind.KING then
            count = count + 1
            output[count] = Move.capture(from, to, moving_piece, captured)
        end
        targets_lo = band(targets_lo, targets_lo - 1)
    end

    while targets_hi ~= 0 do
        local isolated = band(targets_hi, -targets_hi)
        local to = lsb_index[isolated] + 33
        local captured = position.board[to]
        if captured == nil then
            count = count + 1
            output[count] = Move.quiet(from, to, moving_piece)
        elseif Internal.piece_color[captured] ~= color and Internal.piece_kind[captured] ~= PieceKind.KING then
            count = count + 1
            output[count] = Move.capture(from, to, moving_piece, captured)
        end
        targets_hi = band(targets_hi, targets_hi - 1)
    end

    return count
end

local function append_promotions(output, count, from, to, piece, captured)
    if captured == nil then
        output[count + 1] = Move.promote(from, to, piece, Promotion.QUEEN)
        output[count + 2] = Move.promote(from, to, piece, Promotion.ROOK)
        output[count + 3] = Move.promote(from, to, piece, Promotion.BISHOP)
        output[count + 4] = Move.promote(from, to, piece, Promotion.KNIGHT)
    else
        output[count + 1] = Move.promote_capture(from, to, piece, captured, Promotion.QUEEN)
        output[count + 2] = Move.promote_capture(from, to, piece, captured, Promotion.ROOK)
        output[count + 3] = Move.promote_capture(from, to, piece, captured, Promotion.BISHOP)
        output[count + 4] = Move.promote_capture(from, to, piece, captured, Promotion.KNIGHT)
    end
    return count + 4
end

local function append_pawn(position, output, count, color, piece, from)
    local direction = color == Color.WHITE and 8 or -8
    local promotion_rank = color == Color.WHITE and 8 or 1
    local starting_rank = color == Color.WHITE and 2 or 7
    local from_rank = floor((from - 1) / 8) + 1
    local from_file = (from - 1) % 8 + 1
    local one_step = from + direction

    if one_step >= 1 and one_step <= 64 and position.board[one_step] == nil then
        local target_rank = floor((one_step - 1) / 8) + 1
        if target_rank == promotion_rank then
            count = append_promotions(output, count, from, one_step, piece, nil)
        else
            count = count + 1
            output[count] = Move.quiet(from, one_step, piece)

            if from_rank == starting_rank then
                local two_steps = from + direction * 2
                if position.board[two_steps] == nil then
                    count = count + 1
                    output[count] = Move.double_pawn_push(from, two_steps, piece)
                end
            end
        end
    end

    local enemy_pawn = color == Color.WHITE and Piece.BLACK_PAWN or Piece.WHITE_PAWN
    for file_offset = -1, 1, 2 do
        local target_file = from_file + file_offset
        if target_file >= 1 and target_file <= 8 then
            local to = from + direction + file_offset
            local captured = position.board[to]
            if
                captured ~= nil
                and Internal.piece_color[captured] ~= color
                and Internal.piece_kind[captured] ~= PieceKind.KING
            then
                local target_rank = floor((to - 1) / 8) + 1
                if target_rank == promotion_rank then
                    count = append_promotions(output, count, from, to, piece, captured)
                else
                    count = count + 1
                    output[count] = Move.capture(from, to, piece, captured)
                end
            elseif position.en_passant_target == to then
                local captured_square = color == Color.WHITE and to - 8 or to + 8
                if position.board[captured_square] == enemy_pawn then
                    count = count + 1
                    output[count] = Move.en_passant(from, to, color)
                end
            end
        end
    end

    return count
end

local function append_pawn_moves(position, output, count, color)
    local piece = color == Color.WHITE and Piece.WHITE_PAWN or Piece.BLACK_PAWN
    local pawns = position.pieces[piece]
    local pawns_lo = pawns.lo
    local pawns_hi = pawns.hi

    while pawns_lo ~= 0 do
        local isolated = band(pawns_lo, -pawns_lo)
        count = append_pawn(position, output, count, color, piece, lsb_index[isolated] + 1)
        pawns_lo = band(pawns_lo, pawns_lo - 1)
    end
    while pawns_hi ~= 0 do
        local isolated = band(pawns_hi, -pawns_hi)
        count = append_pawn(position, output, count, color, piece, lsb_index[isolated] + 33)
        pawns_hi = band(pawns_hi, pawns_hi - 1)
    end

    return count
end

local function append_leaper_moves(position, output, count, color, piece, attacks_lo, attacks_hi)
    local pieces = position.pieces[piece]
    local pieces_lo = pieces.lo
    local pieces_hi = pieces.hi

    while pieces_lo ~= 0 do
        local isolated = band(pieces_lo, -pieces_lo)
        local from = lsb_index[isolated] + 1
        count = append_target_moves(output, count, position, color, from, piece, attacks_lo[from], attacks_hi[from])
        pieces_lo = band(pieces_lo, pieces_lo - 1)
    end
    while pieces_hi ~= 0 do
        local isolated = band(pieces_hi, -pieces_hi)
        local from = lsb_index[isolated] + 33
        count = append_target_moves(output, count, position, color, from, piece, attacks_lo[from], attacks_hi[from])
        pieces_hi = band(pieces_hi, pieces_hi - 1)
    end

    return count
end

local function append_slider_moves(position, output, count, color, piece, attack_function)
    local pieces = position.pieces[piece]
    local pieces_lo = pieces.lo
    local pieces_hi = pieces.hi
    local occupied_lo = position.occupied.lo
    local occupied_hi = position.occupied.hi

    while pieces_lo ~= 0 do
        local isolated = band(pieces_lo, -pieces_lo)
        local from = lsb_index[isolated] + 1
        local targets_lo, targets_hi = attack_function(from, occupied_lo, occupied_hi)
        count = append_target_moves(output, count, position, color, from, piece, targets_lo, targets_hi)
        pieces_lo = band(pieces_lo, pieces_lo - 1)
    end
    while pieces_hi ~= 0 do
        local isolated = band(pieces_hi, -pieces_hi)
        local from = lsb_index[isolated] + 33
        local targets_lo, targets_hi = attack_function(from, occupied_lo, occupied_hi)
        count = append_target_moves(output, count, position, color, from, piece, targets_lo, targets_hi)
        pieces_hi = band(pieces_hi, pieces_hi - 1)
    end

    return count
end

local function append_castles(position, output, count, color)
    local rights = position.castling_rights
    local board = position.board
    if color == Color.WHITE and board[Square.E1] == Piece.WHITE_KING then
        if
            band(rights, CastlingRights.WHITE_KINGSIDE) ~= 0
            and board[Square.H1] == Piece.WHITE_ROOK
            and board[Square.F1] == nil
            and board[Square.G1] == nil
        then
            count = count + 1
            output[count] = Move.short_castle(color)
        end
        if
            band(rights, CastlingRights.WHITE_QUEENSIDE) ~= 0
            and board[Square.A1] == Piece.WHITE_ROOK
            and board[Square.B1] == nil
            and board[Square.C1] == nil
            and board[Square.D1] == nil
        then
            count = count + 1
            output[count] = Move.long_castle(color)
        end
    elseif color == Color.BLACK and board[Square.E8] == Piece.BLACK_KING then
        if
            band(rights, CastlingRights.BLACK_KINGSIDE) ~= 0
            and board[Square.H8] == Piece.BLACK_ROOK
            and board[Square.F8] == nil
            and board[Square.G8] == nil
        then
            count = count + 1
            output[count] = Move.short_castle(color)
        end
        if
            band(rights, CastlingRights.BLACK_QUEENSIDE) ~= 0
            and board[Square.A8] == Piece.BLACK_ROOK
            and board[Square.B8] == nil
            and board[Square.C8] == nil
            and board[Square.D8] == nil
        then
            count = count + 1
            output[count] = Move.long_castle(color)
        end
    end
    return count
end

function MoveGeneration.write_pseudo_legal_moves(position, output)
    local color = position.side_to_move
    local offset = color == Color.WHITE and 0 or 6
    local count = 0
    count = append_pawn_moves(position, output, count, color)
    count = append_leaper_moves(
        position,
        output,
        count,
        color,
        Piece.WHITE_KNIGHT + offset,
        AttackTables.knight_lo,
        AttackTables.knight_hi
    )
    count = append_slider_moves(position, output, count, color, Piece.WHITE_BISHOP + offset, Attacks.bishop_words)
    count = append_slider_moves(position, output, count, color, Piece.WHITE_ROOK + offset, Attacks.rook_words)
    count = append_slider_moves(position, output, count, color, Piece.WHITE_QUEEN + offset, Attacks.queen_words)
    count = append_leaper_moves(
        position,
        output,
        count,
        color,
        Piece.WHITE_KING + offset,
        AttackTables.king_lo,
        AttackTables.king_hi
    )
    return append_castles(position, output, count, color)
end

local function set_square_words(board, square)
    board.lo = bor(board.lo, mask_lo[square])
    board.hi = bor(board.hi, mask_hi[square])
end

local function analyze(position, state)
    local color = position.side_to_move
    local enemy_color = Color.opposite(color)
    local offset = enemy_color == Color.WHITE and 0 or 6
    local king_square = position.king_square[color]
    local checkers = state.checkers
    local pinned = state.pinned
    Bitboard.clear(checkers)
    Bitboard.clear(pinned)
    Bitboard.clear(state.evasion)

    local enemy_pawns = position.pieces[Piece.WHITE_PAWN + offset]
    checkers.lo = bor(checkers.lo, band(enemy_pawns.lo, AttackTables.pawn_lo[color][king_square]))
    checkers.hi = bor(checkers.hi, band(enemy_pawns.hi, AttackTables.pawn_hi[color][king_square]))

    local enemy_knights = position.pieces[Piece.WHITE_KNIGHT + offset]
    checkers.lo = bor(checkers.lo, band(enemy_knights.lo, AttackTables.knight_lo[king_square]))
    checkers.hi = bor(checkers.hi, band(enemy_knights.hi, AttackTables.knight_hi[king_square]))

    local enemy_king = position.pieces[Piece.WHITE_KING + offset]
    checkers.lo = bor(checkers.lo, band(enemy_king.lo, AttackTables.king_lo[king_square]))
    checkers.hi = bor(checkers.hi, band(enemy_king.hi, AttackTables.king_hi[king_square]))

    local square_rays = AttackTables.rays[king_square]
    for direction = 1, 8 do
        local blocker
        local ray = square_rays[direction]
        for index = 1, #ray do
            local target = ray[index]
            local piece = position.board[target]
            if piece ~= nil then
                if Internal.piece_color[piece] == color then
                    if blocker == nil then
                        blocker = target
                    else
                        break
                    end
                else
                    local kind = Internal.piece_kind[piece]
                    local compatible = kind == PieceKind.QUEEN
                        or (direction <= 4 and kind == PieceKind.ROOK)
                        or (direction >= 5 and kind == PieceKind.BISHOP)
                    if compatible then
                        if blocker == nil then
                            set_square_words(checkers, target)
                        else
                            set_square_words(pinned, blocker)
                        end
                    end
                    break
                end
            end
        end
    end

    state.king_square = king_square
    state.check_count = Bitboard.count(checkers)
    state.checker_square = nil
    if state.check_count == 1 then
        local checker_square = Bitboard.first_square(checkers)
        state.checker_square = checker_square
        set_square_words(state.evasion, checker_square)

        local checker = position.board[checker_square]
        local checker_kind = Internal.piece_kind[checker]
        if checker_kind == PieceKind.BISHOP or checker_kind == PieceKind.ROOK or checker_kind == PieceKind.QUEEN then
            local king_file = (king_square - 1) % 8
            local king_rank = floor((king_square - 1) / 8)
            local checker_file = (checker_square - 1) % 8
            local checker_rank = floor((checker_square - 1) / 8)
            local file_step = checker_file == king_file and 0 or checker_file > king_file and 1 or -1
            local rank_step = checker_rank == king_rank and 0 or checker_rank > king_rank and 1 or -1
            local file = king_file + file_step
            local rank = king_rank + rank_step
            local target = rank * 8 + file + 1
            while target ~= checker_square do
                set_square_words(state.evasion, target)
                file = file + file_step
                rank = rank + rank_step
                target = rank * 8 + file + 1
            end
        end
    end
end

local function is_along_pin(king_square, from, to)
    local king_file = (king_square - 1) % 8
    local king_rank = floor((king_square - 1) / 8)
    local from_file = (from - 1) % 8
    local from_rank = floor((from - 1) / 8)
    local to_file = (to - 1) % 8
    local to_rank = floor((to - 1) / 8)

    if from_file == king_file then
        return to_file == king_file
    end
    if from_rank == king_rank then
        return to_rank == king_rank
    end

    local from_file_delta = from_file - king_file
    local from_rank_delta = from_rank - king_rank
    local to_file_delta = to_file - king_file
    local to_rank_delta = to_rank - king_rank
    return abs(to_file_delta) == abs(to_rank_delta)
        and to_file_delta * from_file_delta >= 0
        and to_rank_delta * from_rank_delta >= 0
end

local function clear_square(lo, hi, square)
    return band(lo, bnot(mask_lo[square])), band(hi, bnot(mask_hi[square]))
end

local function add_square(lo, hi, square)
    return bor(lo, mask_lo[square]), bor(hi, mask_hi[square])
end

local function king_move_is_safe(position, color, from, to)
    local occupied_lo, occupied_hi = clear_square(position.occupied.lo, position.occupied.hi, from)
    occupied_lo, occupied_hi = add_square(occupied_lo, occupied_hi, to)
    local ignored = position.board[to] ~= nil and to or nil
    return not Attacks.is_square_attacked(position, to, Color.opposite(color), occupied_lo, occupied_hi, ignored)
end

local function en_passant_is_safe(position, color, from, to)
    local captured_square = color == Color.WHITE and to - 8 or to + 8
    local occupied_lo, occupied_hi = clear_square(position.occupied.lo, position.occupied.hi, from)
    occupied_lo, occupied_hi = clear_square(occupied_lo, occupied_hi, captured_square)
    occupied_lo, occupied_hi = add_square(occupied_lo, occupied_hi, to)
    return not Attacks.is_square_attacked(
        position,
        position.king_square[color],
        Color.opposite(color),
        occupied_lo,
        occupied_hi,
        captured_square
    )
end

local function castle_is_safe(position, color, special)
    local king_from
    local transit
    local king_to
    local rook_from
    local rook_to
    if color == Color.WHITE then
        king_from = Square.E1
        if special == SpecialMove.SHORT_CASTLE then
            transit, king_to, rook_from, rook_to = Square.F1, Square.G1, Square.H1, Square.F1
        else
            transit, king_to, rook_from, rook_to = Square.D1, Square.C1, Square.A1, Square.D1
        end
    else
        king_from = Square.E8
        if special == SpecialMove.SHORT_CASTLE then
            transit, king_to, rook_from, rook_to = Square.F8, Square.G8, Square.H8, Square.F8
        else
            transit, king_to, rook_from, rook_to = Square.D8, Square.C8, Square.A8, Square.D8
        end
    end

    local occupied_lo, occupied_hi = clear_square(position.occupied.lo, position.occupied.hi, king_from)
    occupied_lo, occupied_hi = add_square(occupied_lo, occupied_hi, transit)
    if Attacks.is_square_attacked(position, transit, Color.opposite(color), occupied_lo, occupied_hi) then
        return false
    end

    occupied_lo, occupied_hi = clear_square(position.occupied.lo, position.occupied.hi, king_from)
    occupied_lo, occupied_hi = clear_square(occupied_lo, occupied_hi, rook_from)
    occupied_lo, occupied_hi = add_square(occupied_lo, occupied_hi, king_to)
    occupied_lo, occupied_hi = add_square(occupied_lo, occupied_hi, rook_to)
    return not Attacks.is_square_attacked(position, king_to, Color.opposite(color), occupied_lo, occupied_hi)
end

function MoveGeneration.new_context()
    return {
        pseudo = {},
        state = {
            checkers = Bitboard.new(),
            pinned = Bitboard.new(),
            evasion = Bitboard.new(),
            king_square = nil,
            checker_square = nil,
            check_count = 0,
        },
    }
end

function MoveGeneration.write_legal_moves(position, output, context)
    context = context or MoveGeneration.new_context()
    local state = context.state
    analyze(position, state)
    local pseudo_count = MoveGeneration.write_pseudo_legal_moves(position, context.pseudo)
    local color = position.side_to_move
    local count = 0

    for index = 1, pseudo_count do
        local move = context.pseudo[index]
        local from = Move.from_square(move)
        local to = Move.to_square(move)
        local piece = Move.piece(move)
        local kind = Internal.piece_kind[piece]
        local special = Move.special_type(move)
        local legal = false

        if kind == PieceKind.KING then
            if special == SpecialMove.SHORT_CASTLE or special == SpecialMove.LONG_CASTLE then
                legal = state.check_count == 0 and castle_is_safe(position, color, special)
            else
                legal = king_move_is_safe(position, color, from, to)
            end
        elseif state.check_count < 2 then
            if special == SpecialMove.EN_PASSANT then
                legal = en_passant_is_safe(position, color, from, to)
            elseif state.check_count == 0 or Bitboard.contains(state.evasion, to) then
                legal = not Bitboard.contains(state.pinned, from) or is_along_pin(state.king_square, from, to)
            end
        end

        if legal then
            count = count + 1
            output[count] = move
        end
    end

    return count
end

Internal.MoveGeneration = MoveGeneration
