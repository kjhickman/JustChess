local _, addon = ...

local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local AttackTables = assert(Internal.AttackTables, "JustChess attack tables must load first")
local Bitboard = assert(Internal.Bitboard, "JustChess bitboard must load first")
local Color = assert(Internal.Color, "JustChess constants must load first")
local Piece = assert(Internal.Piece, "JustChess constants must load first")
local PieceKind = assert(Internal.PieceKind, "JustChess constants must load first")
local band = bit.band
local bnot = bit.bnot
local bor = bit.bor
local frexp = math.frexp

local Attacks = {}
local mask_lo = Bitboard.square_mask_lo
local mask_hi = Bitboard.square_mask_hi
local lsb_index = Bitboard.lsb_index
local ray_lo = AttackTables.ray_lo
local ray_hi = AttackTables.ray_hi
local direction_increases = { true, true, false, false, true, true, false, false }

local function msb_index(word)
    if word < 0 then
        return 31
    end

    local _, exponent = frexp(word)
    return exponent - 1
end

local function first_blocker(blockers_lo, blockers_hi, increasing)
    if increasing then
        if blockers_lo ~= 0 then
            return lsb_index[band(blockers_lo, -blockers_lo)] + 1
        elseif blockers_hi ~= 0 then
            return lsb_index[band(blockers_hi, -blockers_hi)] + 33
        end
    elseif blockers_hi ~= 0 then
        return msb_index(blockers_hi) + 33
    elseif blockers_lo ~= 0 then
        return msb_index(blockers_lo) + 1
    end
end

local function slider_words(square, occupied_lo, occupied_hi, first_direction, last_direction)
    local attacks_lo = 0
    local attacks_hi = 0
    local square_ray_lo = ray_lo[square]
    local square_ray_hi = ray_hi[square]

    for direction = first_direction, last_direction do
        local direction_lo = square_ray_lo[direction]
        local direction_hi = square_ray_hi[direction]
        local blockers_lo = band(occupied_lo, direction_lo)
        local blockers_hi = band(occupied_hi, direction_hi)
        local blocker
        if blockers_lo ~= 0 or blockers_hi ~= 0 then
            blocker = first_blocker(blockers_lo, blockers_hi, direction_increases[direction])
        end

        if blocker ~= nil then
            direction_lo = band(direction_lo, bnot(ray_lo[blocker][direction]))
            direction_hi = band(direction_hi, bnot(ray_hi[blocker][direction]))
        end

        attacks_lo = bor(attacks_lo, direction_lo)
        attacks_hi = bor(attacks_hi, direction_hi)
    end

    return attacks_lo, attacks_hi
end

function Attacks.rook_words(square, occupied_lo, occupied_hi)
    return slider_words(square, occupied_lo, occupied_hi, 1, 4)
end

function Attacks.bishop_words(square, occupied_lo, occupied_hi)
    return slider_words(square, occupied_lo, occupied_hi, 5, 8)
end

function Attacks.queen_words(square, occupied_lo, occupied_hi)
    return slider_words(square, occupied_lo, occupied_hi, 1, 8)
end

local function intersects_except(board, attacks_lo, attacks_hi, ignored_square)
    local intersection_lo = band(board.lo, attacks_lo)
    local intersection_hi = band(board.hi, attacks_hi)
    if ignored_square ~= nil then
        intersection_lo = band(intersection_lo, bnot(mask_lo[ignored_square]))
        intersection_hi = band(intersection_hi, bnot(mask_hi[ignored_square]))
    end
    return intersection_lo ~= 0 or intersection_hi ~= 0
end

function Attacks.is_square_attacked(position, square, by_color, occupied_lo, occupied_hi, ignored_square)
    occupied_lo = occupied_lo or position.occupied.lo
    occupied_hi = occupied_hi or position.occupied.hi

    local pawn = by_color == Color.WHITE and Piece.WHITE_PAWN or Piece.BLACK_PAWN
    local inverse_pawn_color = by_color == Color.WHITE and Color.BLACK or Color.WHITE
    if
        intersects_except(
            position.pieces[pawn],
            AttackTables.pawn_lo[inverse_pawn_color][square],
            AttackTables.pawn_hi[inverse_pawn_color][square],
            ignored_square
        )
    then
        return true
    end

    local knight = by_color == Color.WHITE and Piece.WHITE_KNIGHT or Piece.BLACK_KNIGHT
    if
        intersects_except(
            position.pieces[knight],
            AttackTables.knight_lo[square],
            AttackTables.knight_hi[square],
            ignored_square
        )
    then
        return true
    end

    local king = by_color == Color.WHITE and Piece.WHITE_KING or Piece.BLACK_KING
    if
        intersects_except(
            position.pieces[king],
            AttackTables.king_lo[square],
            AttackTables.king_hi[square],
            ignored_square
        )
    then
        return true
    end

    local square_ray_lo = ray_lo[square]
    local square_ray_hi = ray_hi[square]
    for direction = 1, 8 do
        local blockers_lo = band(occupied_lo, square_ray_lo[direction])
        local blockers_hi = band(occupied_hi, square_ray_hi[direction])
        local target
        if blockers_lo ~= 0 or blockers_hi ~= 0 then
            target = first_blocker(blockers_lo, blockers_hi, direction_increases[direction])
        end

        if target ~= nil and target ~= ignored_square then
            local piece = position.board[target]
            if Internal.piece_color[piece] == by_color then
                local kind = Internal.piece_kind[piece]
                if
                    kind == PieceKind.QUEEN
                    or (direction <= 4 and kind == PieceKind.ROOK)
                    or (direction >= 5 and kind == PieceKind.BISHOP)
                then
                    return true
                end
            end
        end
    end

    return false
end

function Attacks.is_in_check(position, color)
    local king_square = position.king_square[color]
    if king_square == nil then
        return false
    end
    return Attacks.is_square_attacked(position, king_square, Color.opposite(color))
end

Internal.Attacks = Attacks
