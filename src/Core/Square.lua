local _, addon = ...

local Square = assert(addon.JustChess.Square, "JustChess constants must load first")
local floor = math.floor
local byte = string.byte
local char = string.char

function Square.is_valid(square)
    return type(square) == "number" and square >= 1 and square <= 64 and square == floor(square)
end

function Square.from_rank_file(rank, file)
    if type(rank) ~= "number" or type(file) ~= "number" then
        return nil
    end
    if rank < 1 or rank > 8 or file < 1 or file > 8 or rank ~= floor(rank) or file ~= floor(file) then
        return nil
    end
    return (rank - 1) * 8 + file
end

function Square.from_name(name)
    if type(name) ~= "string" or #name ~= 2 then
        return nil
    end

    local file = byte(name, 1) - 96
    local rank = byte(name, 2) - 48
    return Square.from_rank_file(rank, file)
end

function Square.rank(square)
    assert(Square.is_valid(square), "invalid square")
    return floor((square - 1) / 8) + 1
end

function Square.file(square)
    assert(Square.is_valid(square), "invalid square")
    return (square - 1) % 8 + 1
end

function Square.name(square)
    return char(96 + Square.file(square)) .. Square.rank(square)
end
