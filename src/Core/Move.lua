local _, addon = ...

local JustChess = assert(addon.JustChess, "JustChess bootstrap must load first")
local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local Color = assert(Internal.Color, "JustChess constants must load first")
local Piece = assert(Internal.Piece, "JustChess constants must load first")
local Promotion = assert(Internal.Promotion, "JustChess constants must load first")
local SpecialMove = assert(Internal.SpecialMove, "JustChess constants must load first")
local Square = assert(Internal.Square, "JustChess constants must load first")
local floor = math.floor

local TO_FACTOR = 64
local PROMOTION_FACTOR = 4096
local PIECE_FACTOR = 65536
local CAPTURED_FACTOR = 1048576
local SPECIAL_FACTOR = 16777216

local PublicMove = {}
local PackedMove = {}

local function pack(from_square, to_square, promotion, piece, captured_piece, special)
    return (from_square - 1)
        + (to_square - 1) * TO_FACTOR
        + promotion * PROMOTION_FACTOR
        + piece * PIECE_FACTOR
        + captured_piece * CAPTURED_FACTOR
        + special * SPECIAL_FACTOR
end

local function from_square(move)
    return move % 64 + 1
end

local function to_square(move)
    return floor(move / TO_FACTOR) % 64 + 1
end

local function promotion(move)
    return floor(move / PROMOTION_FACTOR) % 16
end

local function piece(move)
    return floor(move / PIECE_FACTOR) % 16
end

local function captured_piece(move)
    return floor(move / CAPTURED_FACTOR) % 16
end

local function is_capture(move)
    return floor(move / CAPTURED_FACTOR) % 16 ~= Piece.NONE
end

local function special_type(move)
    return floor(move / SPECIAL_FACTOR) % 8
end

function PackedMove.quiet(from, to, moving_piece)
    return pack(from, to, Promotion.NONE, moving_piece, Piece.NONE, SpecialMove.NONE)
end

function PackedMove.capture(from, to, moving_piece, captured)
    return pack(from, to, Promotion.NONE, moving_piece, captured, SpecialMove.NONE)
end

function PackedMove.promote(from, to, moving_piece, promoted)
    return pack(from, to, promoted, moving_piece, Piece.NONE, SpecialMove.NONE)
end

function PackedMove.promote_capture(from, to, moving_piece, captured, promoted)
    return pack(from, to, promoted, moving_piece, captured, SpecialMove.NONE)
end

function PackedMove.en_passant(from, to, color)
    if color == Color.WHITE then
        return pack(from, to, Promotion.NONE, Piece.WHITE_PAWN, Piece.BLACK_PAWN, SpecialMove.EN_PASSANT)
    end
    if color == Color.BLACK then
        return pack(from, to, Promotion.NONE, Piece.BLACK_PAWN, Piece.WHITE_PAWN, SpecialMove.EN_PASSANT)
    end
    error("invalid color", 2)
end

function PackedMove.short_castle(color)
    if color == Color.WHITE then
        return pack(Square.E1, Square.G1, Promotion.NONE, Piece.WHITE_KING, Piece.NONE, SpecialMove.SHORT_CASTLE)
    end
    if color == Color.BLACK then
        return pack(Square.E8, Square.G8, Promotion.NONE, Piece.BLACK_KING, Piece.NONE, SpecialMove.SHORT_CASTLE)
    end
    error("invalid color", 2)
end

function PackedMove.long_castle(color)
    if color == Color.WHITE then
        return pack(Square.E1, Square.C1, Promotion.NONE, Piece.WHITE_KING, Piece.NONE, SpecialMove.LONG_CASTLE)
    end
    if color == Color.BLACK then
        return pack(Square.E8, Square.C8, Promotion.NONE, Piece.BLACK_KING, Piece.NONE, SpecialMove.LONG_CASTLE)
    end
    error("invalid color", 2)
end

function PackedMove.double_pawn_push(from, to, moving_piece)
    return pack(from, to, Promotion.NONE, moving_piece, Piece.NONE, SpecialMove.DOUBLE_PAWN_PUSH)
end

PublicMove.to_square = to_square
PublicMove.is_capture = is_capture
function PublicMove.promotion(move)
    local value = promotion(move)
    if value == Promotion.NONE then
        return nil
    end
    return value
end

PackedMove.pack = pack
PackedMove.from_square = from_square
PackedMove.to_square = to_square
PackedMove.promotion = promotion
PackedMove.piece = piece
PackedMove.captured_piece = captured_piece
PackedMove.is_capture = is_capture
PackedMove.special_type = special_type

JustChess.Move = PublicMove
Internal.Move = PackedMove
