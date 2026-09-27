local _, addon = ...

local JustChess = assert(addon.JustChess, "JustChess bootstrap must load first")
local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local AttackTables = assert(Internal.AttackTables, "JustChess attack tables must load first")
local Bitboard = assert(Internal.Bitboard, "JustChess bitboard must load first")
local Color = assert(JustChess.Color, "JustChess constants must load first")
local Piece = assert(JustChess.Piece, "JustChess constants must load first")
local PieceKind = assert(JustChess.PieceKind, "JustChess constants must load first")
local band = bit.band
local bnot = bit.bnot
local bor = bit.bor

local Attacks = {}
local mask_lo = Bitboard.square_mask_lo
local mask_hi = Bitboard.square_mask_hi
local rays = AttackTables.rays

local function contains_words(lo, hi, square)
    return band(lo, mask_lo[square]) ~= 0 or band(hi, mask_hi[square]) ~= 0
end

local function slider_words(square, occupied_lo, occupied_hi, first_direction, last_direction)
    local attacks_lo = 0
    local attacks_hi = 0
    local square_rays = rays[square]

    for direction = first_direction, last_direction do
        local ray = square_rays[direction]
        for index = 1, #ray do
            local target = ray[index]
            attacks_lo = bor(attacks_lo, mask_lo[target])
            attacks_hi = bor(attacks_hi, mask_hi[target])
            if contains_words(occupied_lo, occupied_hi, target) then
                break
            end
        end
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

    local square_rays = rays[square]
    for direction = 1, 8 do
        local ray = square_rays[direction]
        for index = 1, #ray do
            local target = ray[index]
            if contains_words(occupied_lo, occupied_hi, target) then
                local piece = position.board[target]
                if piece ~= nil and target ~= ignored_square and Internal.piece_color[piece] == by_color then
                    local kind = Internal.piece_kind[piece]
                    if kind == PieceKind.QUEEN then
                        return true
                    end
                    if direction <= 4 and kind == PieceKind.ROOK then
                        return true
                    end
                    if direction >= 5 and kind == PieceKind.BISHOP then
                        return true
                    end
                end
                break
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
