local _, addon = ...

local JustChess = assert(addon.JustChess, "JustChess bootstrap must load first")
local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")

local Color = {
    WHITE = 1,
    BLACK = 2,
}

function Color.opposite(color)
    if color == Color.WHITE then
        return Color.BLACK
    end
    if color == Color.BLACK then
        return Color.WHITE
    end
    error("invalid color", 2)
end

local PieceKind = {
    PAWN = 1,
    KNIGHT = 2,
    BISHOP = 3,
    ROOK = 4,
    QUEEN = 5,
    KING = 6,
}

local Piece = {
    NONE = 0,
    WHITE_PAWN = 1,
    WHITE_KNIGHT = 2,
    WHITE_BISHOP = 3,
    WHITE_ROOK = 4,
    WHITE_QUEEN = 5,
    WHITE_KING = 6,
    BLACK_PAWN = 7,
    BLACK_KNIGHT = 8,
    BLACK_BISHOP = 9,
    BLACK_ROOK = 10,
    BLACK_QUEEN = 11,
    BLACK_KING = 12,
}

local piece_color = {
    [Piece.WHITE_PAWN] = Color.WHITE,
    [Piece.WHITE_KNIGHT] = Color.WHITE,
    [Piece.WHITE_BISHOP] = Color.WHITE,
    [Piece.WHITE_ROOK] = Color.WHITE,
    [Piece.WHITE_QUEEN] = Color.WHITE,
    [Piece.WHITE_KING] = Color.WHITE,
    [Piece.BLACK_PAWN] = Color.BLACK,
    [Piece.BLACK_KNIGHT] = Color.BLACK,
    [Piece.BLACK_BISHOP] = Color.BLACK,
    [Piece.BLACK_ROOK] = Color.BLACK,
    [Piece.BLACK_QUEEN] = Color.BLACK,
    [Piece.BLACK_KING] = Color.BLACK,
}

local piece_kind = {
    [Piece.WHITE_PAWN] = PieceKind.PAWN,
    [Piece.WHITE_KNIGHT] = PieceKind.KNIGHT,
    [Piece.WHITE_BISHOP] = PieceKind.BISHOP,
    [Piece.WHITE_ROOK] = PieceKind.ROOK,
    [Piece.WHITE_QUEEN] = PieceKind.QUEEN,
    [Piece.WHITE_KING] = PieceKind.KING,
    [Piece.BLACK_PAWN] = PieceKind.PAWN,
    [Piece.BLACK_KNIGHT] = PieceKind.KNIGHT,
    [Piece.BLACK_BISHOP] = PieceKind.BISHOP,
    [Piece.BLACK_ROOK] = PieceKind.ROOK,
    [Piece.BLACK_QUEEN] = PieceKind.QUEEN,
    [Piece.BLACK_KING] = PieceKind.KING,
}

function Piece.color(piece)
    return piece_color[piece]
end

function Piece.kind(piece)
    return piece_kind[piece]
end

function Piece.from_color_kind(color, kind)
    if type(kind) ~= "number" or kind < PieceKind.PAWN or kind > PieceKind.KING then
        error("invalid piece kind", 2)
    end
    if color == Color.WHITE then
        return kind
    end
    if color == Color.BLACK then
        return kind + 6
    end
    error("invalid color", 2)
end

local Promotion = {
    NONE = 0,
    KNIGHT = 1,
    BISHOP = 2,
    ROOK = 4,
    QUEEN = 8,
}

local SpecialMove = {
    NONE = 0,
    DOUBLE_PAWN_PUSH = 1,
    EN_PASSANT = 2,
    SHORT_CASTLE = 3,
    LONG_CASTLE = 4,
}

local CastlingRights = {
    NONE = 0,
    WHITE_KINGSIDE = 1,
    WHITE_QUEENSIDE = 2,
    BLACK_KINGSIDE = 4,
    BLACK_QUEENSIDE = 8,
    ALL = 15,
}

local Square = {
    COUNT = 64,
}

for rank = 1, 8 do
    for file = 1, 8 do
        local square = (rank - 1) * 8 + file
        Square[string.char(64 + file) .. rank] = square
    end
end

JustChess.Color = Color
JustChess.Piece = {
    WHITE_PAWN = Piece.WHITE_PAWN,
    WHITE_KNIGHT = Piece.WHITE_KNIGHT,
    WHITE_BISHOP = Piece.WHITE_BISHOP,
    WHITE_ROOK = Piece.WHITE_ROOK,
    WHITE_QUEEN = Piece.WHITE_QUEEN,
    WHITE_KING = Piece.WHITE_KING,
    BLACK_PAWN = Piece.BLACK_PAWN,
    BLACK_KNIGHT = Piece.BLACK_KNIGHT,
    BLACK_BISHOP = Piece.BLACK_BISHOP,
    BLACK_ROOK = Piece.BLACK_ROOK,
    BLACK_QUEEN = Piece.BLACK_QUEEN,
    BLACK_KING = Piece.BLACK_KING,
}
JustChess.Promotion = {
    KNIGHT = Promotion.KNIGHT,
    BISHOP = Promotion.BISHOP,
    ROOK = Promotion.ROOK,
    QUEEN = Promotion.QUEEN,
}
JustChess.Square = Square

Internal.Color = Color
Internal.PieceKind = PieceKind
Internal.Piece = Piece
Internal.Promotion = Promotion
Internal.SpecialMove = SpecialMove
Internal.CastlingRights = CastlingRights
Internal.Square = Square
Internal.piece_color = piece_color
Internal.piece_kind = piece_kind
