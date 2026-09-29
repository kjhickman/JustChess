local _, addon = ...

local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local Attacks = assert(Internal.Attacks, "JustChess attacks must load first")
local AttackTables = assert(Internal.AttackTables, "JustChess attack tables must load first")
local Bitboard = assert(Internal.Bitboard, "JustChess bitboard must load first")
local CastlingRights = assert(Internal.CastlingRights, "JustChess constants must load first")
local Color = assert(Internal.Color, "JustChess constants must load first")
local Move = assert(Internal.Move, "JustChess move must load first")
local Piece = assert(Internal.Piece, "JustChess constants must load first")
local PieceKind = assert(Internal.PieceKind, "JustChess constants must load first")
local Promotion = assert(Internal.Promotion, "JustChess constants must load first")
local Square = assert(Internal.Square, "JustChess constants must load first")
local band = bit.band
local bnot = bit.bnot
local bor = bit.bor
local floor = math.floor

local MoveGeneration = {}

local mask_lo = Bitboard.square_mask_lo
local mask_hi = Bitboard.square_mask_hi
local lsb_index = Bitboard.lsb_index

local ordinary_move_is_legal
local en_passant_is_safe

local function append_target_moves(output, count, position, from, moving_piece, targets_lo, targets_hi)
    if output == nil then
        while targets_lo ~= 0 do
            count = count + 1
            targets_lo = band(targets_lo, targets_lo - 1)
        end
        while targets_hi ~= 0 do
            count = count + 1
            targets_hi = band(targets_hi, targets_hi - 1)
        end
        return count
    end

    while targets_lo ~= 0 do
        local isolated = band(targets_lo, -targets_lo)
        local to = lsb_index[isolated] + 1
        local captured = position.board[to]
        count = count + 1
        if captured == nil then
            output[count] = Move.quiet(from, to, moving_piece)
        else
            output[count] = Move.capture(from, to, moving_piece, captured)
        end
        targets_lo = band(targets_lo, targets_lo - 1)
    end

    while targets_hi ~= 0 do
        local isolated = band(targets_hi, -targets_hi)
        local to = lsb_index[isolated] + 33
        local captured = position.board[to]
        count = count + 1
        if captured == nil then
            output[count] = Move.quiet(from, to, moving_piece)
        else
            output[count] = Move.capture(from, to, moving_piece, captured)
        end
        targets_hi = band(targets_hi, targets_hi - 1)
    end

    return count
end

local function append_promotions(output, count, from, to, piece, captured)
    if output == nil then
        return count + 4
    end
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

local function append_pawn(position, output, count, color, piece, from, state)
    local direction = color == Color.WHITE and 8 or -8
    local promotion_rank = color == Color.WHITE and 8 or 1
    local starting_rank = color == Color.WHITE and 2 or 7
    local from_rank = floor((from - 1) / 8) + 1
    local from_file = (from - 1) % 8 + 1
    local one_step = from + direction
    local pinned = Bitboard.contains(state.pinned, from)

    if one_step >= 1 and one_step <= 64 and position.board[one_step] == nil then
        local target_rank = floor((one_step - 1) / 8) + 1
        if target_rank == promotion_rank then
            if ordinary_move_is_legal(state, pinned, from, one_step) then
                count = append_promotions(output, count, from, one_step, piece, nil)
            end
        else
            if ordinary_move_is_legal(state, pinned, from, one_step) then
                count = count + 1
                if output ~= nil then
                    output[count] = Move.quiet(from, one_step, piece)
                end
            end

            if from_rank == starting_rank then
                local two_steps = from + direction * 2
                if position.board[two_steps] == nil and ordinary_move_is_legal(state, pinned, from, two_steps) then
                    count = count + 1
                    if output ~= nil then
                        output[count] = Move.double_pawn_push(from, two_steps, piece)
                    end
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
                if ordinary_move_is_legal(state, pinned, from, to) then
                    local target_rank = floor((to - 1) / 8) + 1
                    if target_rank == promotion_rank then
                        count = append_promotions(output, count, from, to, piece, captured)
                    else
                        count = count + 1
                        if output ~= nil then
                            output[count] = Move.capture(from, to, piece, captured)
                        end
                    end
                end
            elseif position.en_passant_target == to then
                local captured_square = color == Color.WHITE and to - 8 or to + 8
                if position.board[captured_square] == enemy_pawn and en_passant_is_safe(position, color, from, to) then
                    count = count + 1
                    if output ~= nil then
                        output[count] = Move.en_passant(from, to, color)
                    end
                end
            end
        end
    end

    return count
end

local function append_pawn_moves(position, output, count, color, state)
    local piece = color == Color.WHITE and Piece.WHITE_PAWN or Piece.BLACK_PAWN
    local pawns = position.pieces[piece]
    local pawns_lo = pawns.lo
    local pawns_hi = pawns.hi

    while pawns_lo ~= 0 do
        local isolated = band(pawns_lo, -pawns_lo)
        count = append_pawn(position, output, count, color, piece, lsb_index[isolated] + 1, state)
        pawns_lo = band(pawns_lo, pawns_lo - 1)
    end
    while pawns_hi ~= 0 do
        local isolated = band(pawns_hi, -pawns_hi)
        count = append_pawn(position, output, count, color, piece, lsb_index[isolated] + 33, state)
        pawns_hi = band(pawns_hi, pawns_hi - 1)
    end

    return count
end

local function append_knight_moves(position, output, count, piece, dest_lo, dest_hi, state)
    local pieces = position.pieces[piece]
    local pieces_lo = band(pieces.lo, bnot(state.pinned.lo))
    local pieces_hi = band(pieces.hi, bnot(state.pinned.hi))

    while pieces_lo ~= 0 do
        local isolated = band(pieces_lo, -pieces_lo)
        local from = lsb_index[isolated] + 1
        local targets_lo = band(AttackTables.knight_lo[from], dest_lo)
        local targets_hi = band(AttackTables.knight_hi[from], dest_hi)
        count = append_target_moves(output, count, position, from, piece, targets_lo, targets_hi)
        pieces_lo = band(pieces_lo, pieces_lo - 1)
    end
    while pieces_hi ~= 0 do
        local isolated = band(pieces_hi, -pieces_hi)
        local from = lsb_index[isolated] + 33
        local targets_lo = band(AttackTables.knight_lo[from], dest_lo)
        local targets_hi = band(AttackTables.knight_hi[from], dest_hi)
        count = append_target_moves(output, count, position, from, piece, targets_lo, targets_hi)
        pieces_hi = band(pieces_hi, pieces_hi - 1)
    end

    return count
end

local function append_slider_moves(position, output, count, piece, attack_function, dest_lo, dest_hi, state)
    local pieces = position.pieces[piece]
    local pieces_lo = pieces.lo
    local pieces_hi = pieces.hi
    local occupied_lo = position.occupied.lo
    local occupied_hi = position.occupied.hi
    local pinned = state.pinned

    while pieces_lo ~= 0 do
        local isolated = band(pieces_lo, -pieces_lo)
        local from = lsb_index[isolated] + 1
        local targets_lo, targets_hi = attack_function(from, occupied_lo, occupied_hi)
        targets_lo = band(targets_lo, dest_lo)
        targets_hi = band(targets_hi, dest_hi)
        if band(pinned.lo, isolated) ~= 0 then
            targets_lo = band(targets_lo, state.pin_lo[from])
            targets_hi = band(targets_hi, state.pin_hi[from])
        end
        count = append_target_moves(output, count, position, from, piece, targets_lo, targets_hi)
        pieces_lo = band(pieces_lo, pieces_lo - 1)
    end
    while pieces_hi ~= 0 do
        local isolated = band(pieces_hi, -pieces_hi)
        local from = lsb_index[isolated] + 33
        local targets_lo, targets_hi = attack_function(from, occupied_lo, occupied_hi)
        targets_lo = band(targets_lo, dest_lo)
        targets_hi = band(targets_hi, dest_hi)
        if band(pinned.hi, isolated) ~= 0 then
            targets_lo = band(targets_lo, state.pin_lo[from])
            targets_hi = band(targets_hi, state.pin_hi[from])
        end
        count = append_target_moves(output, count, position, from, piece, targets_lo, targets_hi)
        pieces_hi = band(pieces_hi, pieces_hi - 1)
    end

    return count
end

local function add_leaper_attacks(danger_lo, danger_hi, pieces, attacks_lo, attacks_hi)
    local pieces_lo = pieces.lo
    local pieces_hi = pieces.hi
    while pieces_lo ~= 0 do
        local square = lsb_index[band(pieces_lo, -pieces_lo)] + 1
        danger_lo = bor(danger_lo, attacks_lo[square])
        danger_hi = bor(danger_hi, attacks_hi[square])
        pieces_lo = band(pieces_lo, pieces_lo - 1)
    end
    while pieces_hi ~= 0 do
        local square = lsb_index[band(pieces_hi, -pieces_hi)] + 33
        danger_lo = bor(danger_lo, attacks_lo[square])
        danger_hi = bor(danger_hi, attacks_hi[square])
        pieces_hi = band(pieces_hi, pieces_hi - 1)
    end
    return danger_lo, danger_hi
end

local function add_slider_attacks(danger_lo, danger_hi, pieces_lo, pieces_hi, attack_function, occupied_lo, occupied_hi)
    while pieces_lo ~= 0 do
        local attacks_lo, attacks_hi =
            attack_function(lsb_index[band(pieces_lo, -pieces_lo)] + 1, occupied_lo, occupied_hi)
        danger_lo = bor(danger_lo, attacks_lo)
        danger_hi = bor(danger_hi, attacks_hi)
        pieces_lo = band(pieces_lo, pieces_lo - 1)
    end
    while pieces_hi ~= 0 do
        local attacks_lo, attacks_hi =
            attack_function(lsb_index[band(pieces_hi, -pieces_hi)] + 33, occupied_lo, occupied_hi)
        danger_lo = bor(danger_lo, attacks_lo)
        danger_hi = bor(danger_hi, attacks_hi)
        pieces_hi = band(pieces_hi, pieces_hi - 1)
    end
    return danger_lo, danger_hi
end

local function clear_square(lo, hi, square)
    return band(lo, bnot(mask_lo[square])), band(hi, bnot(mask_hi[square]))
end

-- The king is removed from occupancy so sliders attack through it; otherwise it could retreat along a checking ray.
local function ensure_danger(position, state)
    if state.danger_ready then
        return
    end

    local enemy_color = Color.opposite(position.side_to_move)
    local offset = enemy_color == Color.WHITE and 0 or 6
    local occupied_lo, occupied_hi = clear_square(position.occupied.lo, position.occupied.hi, state.king_square)
    local bishops = position.pieces[Piece.WHITE_BISHOP + offset]
    local rooks = position.pieces[Piece.WHITE_ROOK + offset]
    local queens = position.pieces[Piece.WHITE_QUEEN + offset]

    local danger_lo, danger_hi = add_leaper_attacks(
        0,
        0,
        position.pieces[Piece.WHITE_PAWN + offset],
        AttackTables.pawn_lo[enemy_color],
        AttackTables.pawn_hi[enemy_color]
    )
    danger_lo, danger_hi = add_leaper_attacks(
        danger_lo,
        danger_hi,
        position.pieces[Piece.WHITE_KNIGHT + offset],
        AttackTables.knight_lo,
        AttackTables.knight_hi
    )
    danger_lo, danger_hi = add_leaper_attacks(
        danger_lo,
        danger_hi,
        position.pieces[Piece.WHITE_KING + offset],
        AttackTables.king_lo,
        AttackTables.king_hi
    )
    danger_lo, danger_hi = add_slider_attacks(
        danger_lo,
        danger_hi,
        bor(rooks.lo, queens.lo),
        bor(rooks.hi, queens.hi),
        Attacks.rook_words,
        occupied_lo,
        occupied_hi
    )
    danger_lo, danger_hi = add_slider_attacks(
        danger_lo,
        danger_hi,
        bor(bishops.lo, queens.lo),
        bor(bishops.hi, queens.hi),
        Attacks.bishop_words,
        occupied_lo,
        occupied_hi
    )
    state.danger.lo = danger_lo
    state.danger.hi = danger_hi
    state.danger_ready = true
end

local function castle_is_safe(position, state, transit, king_to)
    ensure_danger(position, state)
    return not Bitboard.contains(state.danger, transit) and not Bitboard.contains(state.danger, king_to)
end

local function append_castles(position, output, count, color, state)
    if state.check_count ~= 0 then
        return count
    end

    local rights = position.castling_rights
    local board = position.board
    if color == Color.WHITE and board[Square.E1] == Piece.WHITE_KING then
        if
            band(rights, CastlingRights.WHITE_KINGSIDE) ~= 0
            and board[Square.H1] == Piece.WHITE_ROOK
            and board[Square.F1] == nil
            and board[Square.G1] == nil
            and castle_is_safe(position, state, Square.F1, Square.G1)
        then
            count = count + 1
            if output ~= nil then
                output[count] = Move.short_castle(color)
            end
        end
        if
            band(rights, CastlingRights.WHITE_QUEENSIDE) ~= 0
            and board[Square.A1] == Piece.WHITE_ROOK
            and board[Square.B1] == nil
            and board[Square.C1] == nil
            and board[Square.D1] == nil
            and castle_is_safe(position, state, Square.D1, Square.C1)
        then
            count = count + 1
            if output ~= nil then
                output[count] = Move.long_castle(color)
            end
        end
    elseif color == Color.BLACK and board[Square.E8] == Piece.BLACK_KING then
        if
            band(rights, CastlingRights.BLACK_KINGSIDE) ~= 0
            and board[Square.H8] == Piece.BLACK_ROOK
            and board[Square.F8] == nil
            and board[Square.G8] == nil
            and castle_is_safe(position, state, Square.F8, Square.G8)
        then
            count = count + 1
            if output ~= nil then
                output[count] = Move.short_castle(color)
            end
        end
        if
            band(rights, CastlingRights.BLACK_QUEENSIDE) ~= 0
            and board[Square.A8] == Piece.BLACK_ROOK
            and board[Square.B8] == nil
            and board[Square.C8] == nil
            and board[Square.D8] == nil
            and castle_is_safe(position, state, Square.D8, Square.C8)
        then
            count = count + 1
            if output ~= nil then
                output[count] = Move.long_castle(color)
            end
        end
    end
    return count
end

local function write_moves(position, output, state)
    local color = position.side_to_move
    local offset = color == Color.WHITE and 0 or 6
    local enemy_pawn = position.pieces[Piece.BLACK_PAWN - offset]
    local enemy_knight = position.pieces[Piece.BLACK_KNIGHT - offset]
    local enemy_bishop = position.pieces[Piece.BLACK_BISHOP - offset]
    local enemy_rook = position.pieces[Piece.BLACK_ROOK - offset]
    local enemy_queen = position.pieces[Piece.BLACK_QUEEN - offset]
    local target_mask_lo =
        bor(bnot(position.occupied.lo), enemy_pawn.lo, enemy_knight.lo, enemy_bishop.lo, enemy_rook.lo, enemy_queen.lo)
    local target_mask_hi =
        bor(bnot(position.occupied.hi), enemy_pawn.hi, enemy_knight.hi, enemy_bishop.hi, enemy_rook.hi, enemy_queen.hi)
    local count = 0
    if state.check_count < 2 then
        local dest_lo = band(target_mask_lo, state.evasion.lo)
        local dest_hi = band(target_mask_hi, state.evasion.hi)
        count = append_pawn_moves(position, output, count, color, state)
        count = append_knight_moves(position, output, count, Piece.WHITE_KNIGHT + offset, dest_lo, dest_hi, state)
        count = append_slider_moves(
            position,
            output,
            count,
            Piece.WHITE_BISHOP + offset,
            Attacks.bishop_words,
            dest_lo,
            dest_hi,
            state
        )
        count = append_slider_moves(
            position,
            output,
            count,
            Piece.WHITE_ROOK + offset,
            Attacks.rook_words,
            dest_lo,
            dest_hi,
            state
        )
        count = append_slider_moves(
            position,
            output,
            count,
            Piece.WHITE_QUEEN + offset,
            Attacks.queen_words,
            dest_lo,
            dest_hi,
            state
        )
    end
    local king_square = state.king_square
    local king_lo = band(AttackTables.king_lo[king_square], target_mask_lo)
    local king_hi = band(AttackTables.king_hi[king_square], target_mask_hi)
    if king_lo ~= 0 or king_hi ~= 0 then
        ensure_danger(position, state)
        king_lo = band(king_lo, bnot(state.danger.lo))
        king_hi = band(king_hi, bnot(state.danger.hi))
        count = append_target_moves(output, count, position, king_square, Piece.WHITE_KING + offset, king_lo, king_hi)
    end
    return append_castles(position, output, count, color, state)
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
                            state.pin_lo[blocker] = AttackTables.ray_lo[king_square][direction]
                            state.pin_hi[blocker] = AttackTables.ray_hi[king_square][direction]
                        end
                    end
                    break
                end
            end
        end
    end

    state.king_square = king_square
    state.check_count = Bitboard.count(checkers)
    state.danger_ready = false
    if state.check_count == 0 then
        state.evasion.lo = -1
        state.evasion.hi = -1
    elseif state.check_count == 1 then
        local checker_square = Bitboard.first_square(checkers)
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

ordinary_move_is_legal = function(state, pinned, from, to)
    return (state.check_count == 0 or Bitboard.contains(state.evasion, to))
        and (not pinned or band(state.pin_lo[from], mask_lo[to]) ~= 0 or band(state.pin_hi[from], mask_hi[to]) ~= 0)
end

local function add_square(lo, hi, square)
    return bor(lo, mask_lo[square]), bor(hi, mask_hi[square])
end

en_passant_is_safe = function(position, color, from, to)
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

function MoveGeneration.new_context()
    return {
        state = {
            checkers = Bitboard.new(),
            pinned = Bitboard.new(),
            pin_lo = {},
            pin_hi = {},
            evasion = Bitboard.new(),
            danger = Bitboard.new(),
            danger_ready = false,
            king_square = nil,
            check_count = 0,
        },
    }
end

function MoveGeneration.write_legal_moves(position, output, context)
    context = context or MoveGeneration.new_context()
    local state = context.state
    analyze(position, state)
    return write_moves(position, output, state)
end

Internal.MoveGeneration = MoveGeneration
