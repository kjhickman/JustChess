local _, addon = ...

local JustChess = assert(addon.JustChess, "JustChess bootstrap must load first")
local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local Bitboard = assert(Internal.Bitboard, "JustChess bitboard must load first")
local Color = assert(JustChess.Color, "JustChess constants must load first")
local floor = math.floor

local AttackTables = {
    knight_lo = {},
    knight_hi = {},
    king_lo = {},
    king_hi = {},
    pawn_lo = {
        [Color.WHITE] = {},
        [Color.BLACK] = {},
    },
    pawn_hi = {
        [Color.WHITE] = {},
        [Color.BLACK] = {},
    },
    rays = {},
}

local direction_file = { 0, 1, 0, -1, 1, -1, 1, -1 }
local direction_rank = { 1, 0, -1, 0, 1, 1, -1, -1 }
local knight_file = { 1, 2, 2, 1, -1, -2, -2, -1 }
local knight_rank = { 2, 1, -1, -2, -2, -1, 1, 2 }

local function add_square(lo, hi, square)
    return bit.bor(lo, Bitboard.square_mask_lo[square]), bit.bor(hi, Bitboard.square_mask_hi[square])
end

for square = 1, 64 do
    local origin = square - 1
    local origin_file = origin % 8
    local origin_rank = floor(origin / 8)
    local knight_lo = 0
    local knight_hi = 0
    local king_lo = 0
    local king_hi = 0
    local white_pawn_lo = 0
    local white_pawn_hi = 0
    local black_pawn_lo = 0
    local black_pawn_hi = 0

    for index = 1, 8 do
        local file = origin_file + knight_file[index]
        local rank = origin_rank + knight_rank[index]
        if file >= 0 and file < 8 and rank >= 0 and rank < 8 then
            knight_lo, knight_hi = add_square(knight_lo, knight_hi, rank * 8 + file + 1)
        end
    end

    for file_offset = -1, 1 do
        for rank_offset = -1, 1 do
            if file_offset ~= 0 or rank_offset ~= 0 then
                local file = origin_file + file_offset
                local rank = origin_rank + rank_offset
                if file >= 0 and file < 8 and rank >= 0 and rank < 8 then
                    king_lo, king_hi = add_square(king_lo, king_hi, rank * 8 + file + 1)
                end
            end
        end
    end

    if origin_rank < 7 then
        if origin_file > 0 then
            white_pawn_lo, white_pawn_hi = add_square(white_pawn_lo, white_pawn_hi, square + 7)
        end
        if origin_file < 7 then
            white_pawn_lo, white_pawn_hi = add_square(white_pawn_lo, white_pawn_hi, square + 9)
        end
    end

    if origin_rank > 0 then
        if origin_file > 0 then
            black_pawn_lo, black_pawn_hi = add_square(black_pawn_lo, black_pawn_hi, square - 9)
        end
        if origin_file < 7 then
            black_pawn_lo, black_pawn_hi = add_square(black_pawn_lo, black_pawn_hi, square - 7)
        end
    end

    AttackTables.knight_lo[square] = knight_lo
    AttackTables.knight_hi[square] = knight_hi
    AttackTables.king_lo[square] = king_lo
    AttackTables.king_hi[square] = king_hi
    AttackTables.pawn_lo[Color.WHITE][square] = white_pawn_lo
    AttackTables.pawn_hi[Color.WHITE][square] = white_pawn_hi
    AttackTables.pawn_lo[Color.BLACK][square] = black_pawn_lo
    AttackTables.pawn_hi[Color.BLACK][square] = black_pawn_hi

    local rays = {}
    AttackTables.rays[square] = rays
    for direction = 1, 8 do
        local ray = {}
        rays[direction] = ray
        local file = origin_file + direction_file[direction]
        local rank = origin_rank + direction_rank[direction]
        while file >= 0 and file < 8 and rank >= 0 and rank < 8 do
            ray[#ray + 1] = rank * 8 + file + 1
            file = file + direction_file[direction]
            rank = rank + direction_rank[direction]
        end
    end
end

Internal.AttackTables = AttackTables
