local _, addon = ...

local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local Square = assert(addon.JustChess.Square, "JustChess constants must load first")
local bitlib = bit
local band = bitlib.band
local bnot = bitlib.bnot
local bor = bitlib.bor
local lshift = bitlib.lshift
local rshift = bitlib.rshift

local Bitboard = {}
local square_mask_lo = {}
local square_mask_hi = {}
local lsb_index = {}
local byte_count = { [0] = 0 }

for index = 0, 31 do
    lsb_index[lshift(1, index)] = index
end

for value = 1, 255 do
    byte_count[value] = byte_count[rshift(value, 1)] + band(value, 1)
end

for square = 1, Square.COUNT do
    if square <= 32 then
        square_mask_lo[square] = lshift(1, square - 1)
        square_mask_hi[square] = 0
    else
        square_mask_lo[square] = 0
        square_mask_hi[square] = lshift(1, square - 33)
    end
end

function Bitboard.new(lo, hi)
    return { lo = lo or 0, hi = hi or 0 }
end

function Bitboard.clear(board)
    board.lo = 0
    board.hi = 0
end

function Bitboard.copy_into(output, board)
    output.lo = board.lo
    output.hi = board.hi
end

function Bitboard.contains(board, square)
    return band(board.lo, square_mask_lo[square]) ~= 0 or band(board.hi, square_mask_hi[square]) ~= 0
end

function Bitboard.set(board, square)
    board.lo = bor(board.lo, square_mask_lo[square])
    board.hi = bor(board.hi, square_mask_hi[square])
end

function Bitboard.unset(board, square)
    board.lo = band(board.lo, bnot(square_mask_lo[square]))
    board.hi = band(board.hi, bnot(square_mask_hi[square]))
end

function Bitboard.move(board, from_square, to_square)
    board.lo = bor(band(board.lo, bnot(square_mask_lo[from_square])), square_mask_lo[to_square])
    board.hi = bor(band(board.hi, bnot(square_mask_hi[from_square])), square_mask_hi[to_square])
end

function Bitboard.count(board)
    local lo = board.lo
    local hi = board.hi
    return byte_count[band(lo, 0xFF)]
        + byte_count[band(rshift(lo, 8), 0xFF)]
        + byte_count[band(rshift(lo, 16), 0xFF)]
        + byte_count[band(rshift(lo, 24), 0xFF)]
        + byte_count[band(hi, 0xFF)]
        + byte_count[band(rshift(hi, 8), 0xFF)]
        + byte_count[band(rshift(hi, 16), 0xFF)]
        + byte_count[band(rshift(hi, 24), 0xFF)]
end

function Bitboard.first_square(board)
    local word = board.lo
    if word ~= 0 then
        return lsb_index[band(word, -word)] + 1
    end

    word = board.hi
    if word ~= 0 then
        return lsb_index[band(word, -word)] + 33
    end

    return nil
end

Bitboard.square_mask_lo = square_mask_lo
Bitboard.square_mask_hi = square_mask_hi
Bitboard.lsb_index = lsb_index

Internal.Bitboard = Bitboard
