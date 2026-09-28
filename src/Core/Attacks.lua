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
local lshift = bit.lshift

local Attacks = {}
local mask_lo = Bitboard.square_mask_lo
local mask_hi = Bitboard.square_mask_hi
local lsb_index = Bitboard.lsb_index
local ray_lo = AttackTables.ray_lo
local ray_hi = AttackTables.ray_hi
local direction_increases = { true, true, false, false, true, true, false, false }

local function slider_words(square_ray_lo, square_ray_hi, occupied_lo, occupied_hi, first_direction)
    local attacks_lo = 0
    local attacks_hi = 0

    -- Increasing rays keep every bit through the least blocker.
    for direction = first_direction, first_direction + 1 do
        local direction_lo = square_ray_lo[direction]
        local direction_hi = square_ray_hi[direction]
        local blockers_lo = band(occupied_lo, direction_lo)
        if blockers_lo ~= 0 then
            local blocker = band(blockers_lo, -blockers_lo)
            direction_lo = band(direction_lo, bor(blocker, blocker - 1))
            direction_hi = 0
        else
            local blockers_hi = band(occupied_hi, direction_hi)
            if blockers_hi ~= 0 then
                local blocker = band(blockers_hi, -blockers_hi)
                direction_hi = band(direction_hi, bor(blocker, blocker - 1))
            end
        end

        attacks_lo = bor(attacks_lo, direction_lo)
        attacks_hi = bor(attacks_hi, direction_hi)
    end

    -- Decreasing rays keep every bit from the greatest blocker.
    for direction = first_direction + 2, first_direction + 3 do
        local direction_lo = square_ray_lo[direction]
        local direction_hi = square_ray_hi[direction]
        local blockers_hi = band(occupied_hi, direction_hi)
        if blockers_hi ~= 0 then
            local blocker = -2147483648
            if blockers_hi > 0 then
                local _, exponent = frexp(blockers_hi)
                blocker = lshift(1, exponent - 1)
            end
            direction_lo = 0
            direction_hi = band(direction_hi, bnot(blocker - 1))
        else
            local blockers_lo = band(occupied_lo, direction_lo)
            if blockers_lo ~= 0 then
                local blocker = -2147483648
                if blockers_lo > 0 then
                    local _, exponent = frexp(blockers_lo)
                    blocker = lshift(1, exponent - 1)
                end
                direction_lo = band(direction_lo, bnot(blocker - 1))
            end
        end

        attacks_lo = bor(attacks_lo, direction_lo)
        attacks_hi = bor(attacks_hi, direction_hi)
    end

    return attacks_lo, attacks_hi
end

function Attacks.rook_words(square, occupied_lo, occupied_hi)
    return slider_words(ray_lo[square], ray_hi[square], occupied_lo, occupied_hi, 1)
end

function Attacks.bishop_words(square, occupied_lo, occupied_hi)
    return slider_words(ray_lo[square], ray_hi[square], occupied_lo, occupied_hi, 5)
end

function Attacks.queen_words(square, occupied_lo, occupied_hi)
    local square_ray_lo = ray_lo[square]
    local square_ray_hi = ray_hi[square]
    local rook_lo, rook_hi = slider_words(square_ray_lo, square_ray_hi, occupied_lo, occupied_hi, 1)
    local bishop_lo, bishop_hi = slider_words(square_ray_lo, square_ray_hi, occupied_lo, occupied_hi, 5)
    return bor(rook_lo, bishop_lo), bor(rook_hi, bishop_hi)
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
        local target
        if direction_increases[direction] then
            local blockers_lo = band(occupied_lo, square_ray_lo[direction])
            if blockers_lo ~= 0 then
                target = lsb_index[band(blockers_lo, -blockers_lo)] + 1
            else
                local blockers_hi = band(occupied_hi, square_ray_hi[direction])
                if blockers_hi ~= 0 then
                    target = lsb_index[band(blockers_hi, -blockers_hi)] + 33
                end
            end
        else
            local blockers_hi = band(occupied_hi, square_ray_hi[direction])
            if blockers_hi ~= 0 then
                if blockers_hi < 0 then
                    target = 64
                else
                    local _, exponent = frexp(blockers_hi)
                    target = exponent + 32
                end
            else
                local blockers_lo = band(occupied_lo, square_ray_lo[direction])
                if blockers_lo < 0 then
                    target = 32
                elseif blockers_lo ~= 0 then
                    local _, exponent = frexp(blockers_lo)
                    target = exponent
                end
            end
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
