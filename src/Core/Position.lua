local _, addon = ...

local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local Bitboard = assert(Internal.Bitboard, "JustChess bitboard must load first")
local CastlingRights = assert(Internal.CastlingRights, "JustChess constants must load first")
local Color = assert(Internal.Color, "JustChess constants must load first")
local Piece = assert(Internal.Piece, "JustChess constants must load first")
local Square = assert(Internal.Square, "JustChess constants must load first")

local Position = {}

local back_rank = {
    Piece.WHITE_ROOK,
    Piece.WHITE_KNIGHT,
    Piece.WHITE_BISHOP,
    Piece.WHITE_QUEEN,
    Piece.WHITE_KING,
    Piece.WHITE_BISHOP,
    Piece.WHITE_KNIGHT,
    Piece.WHITE_ROOK,
}

local function add_piece(position, square, piece)
    Bitboard.set(position.pieces[piece], square)
    Bitboard.set(position.occupied, square)
    position.board[square] = piece

    if piece == Piece.WHITE_KING then
        position.king_square[Color.WHITE] = square
    elseif piece == Piece.BLACK_KING then
        position.king_square[Color.BLACK] = square
    end
end

local function remove_piece(position, square, piece)
    Bitboard.unset(position.pieces[piece], square)
    Bitboard.unset(position.occupied, square)
    position.board[square] = nil

    if piece == Piece.WHITE_KING then
        position.king_square[Color.WHITE] = nil
    elseif piece == Piece.BLACK_KING then
        position.king_square[Color.BLACK] = nil
    end
end

local function move_piece(position, from_square, to_square, piece)
    Bitboard.move(position.pieces[piece], from_square, to_square)
    Bitboard.move(position.occupied, from_square, to_square)
    position.board[from_square] = nil
    position.board[to_square] = piece

    if piece == Piece.WHITE_KING then
        position.king_square[Color.WHITE] = to_square
    elseif piece == Piece.BLACK_KING then
        position.king_square[Color.BLACK] = to_square
    end
end

local function allocate()
    local pieces = {}
    for piece = Piece.WHITE_PAWN, Piece.BLACK_KING do
        pieces[piece] = Bitboard.new()
    end

    return {
        pieces = pieces,
        occupied = Bitboard.new(),
        board = {},
        king_square = {},
        side_to_move = Color.WHITE,
        castling_rights = CastlingRights.NONE,
        en_passant_target = nil,
        halfmove_clock = 0,
        fullmove_number = 1,
    }
end

function Position.clear(position)
    for piece = Piece.WHITE_PAWN, Piece.BLACK_KING do
        Bitboard.clear(position.pieces[piece])
    end
    Bitboard.clear(position.occupied)

    for square = 1, Square.COUNT do
        position.board[square] = nil
    end

    position.king_square[Color.WHITE] = nil
    position.king_square[Color.BLACK] = nil
    position.side_to_move = Color.WHITE
    position.castling_rights = CastlingRights.NONE
    position.en_passant_target = nil
    position.halfmove_clock = 0
    position.fullmove_number = 1
end

function Position.reset(position)
    Position.clear(position)

    for file = 1, 8 do
        add_piece(position, 8 + file, Piece.WHITE_PAWN)
        add_piece(position, 48 + file, Piece.BLACK_PAWN)
        add_piece(position, file, back_rank[file])
        add_piece(position, 56 + file, back_rank[file] + 6)
    end

    position.castling_rights = CastlingRights.ALL
end

function Position.new()
    local position = allocate()
    Position.reset(position)
    return position
end

function Position.new_empty()
    return allocate()
end

function Position.piece_at(position, square)
    assert(Square.is_valid(square), "invalid square")
    return position.board[square]
end

function Position.set_piece(position, square, piece)
    assert(Square.is_valid(square), "invalid square")
    assert(type(piece) == "number" and piece >= Piece.NONE and piece <= Piece.BLACK_KING, "invalid piece")

    local current = position.board[square]
    if current ~= nil then
        remove_piece(position, square, current)
    end
    if piece ~= Piece.NONE then
        add_piece(position, square, piece)
    end
end

function Position.clone(position)
    local clone = allocate()
    for piece = Piece.WHITE_PAWN, Piece.BLACK_KING do
        Bitboard.copy_into(clone.pieces[piece], position.pieces[piece])
    end
    Bitboard.copy_into(clone.occupied, position.occupied)

    for square = 1, Square.COUNT do
        clone.board[square] = position.board[square]
    end
    clone.king_square[Color.WHITE] = position.king_square[Color.WHITE]
    clone.king_square[Color.BLACK] = position.king_square[Color.BLACK]
    clone.side_to_move = position.side_to_move
    clone.castling_rights = position.castling_rights
    clone.en_passant_target = position.en_passant_target
    clone.halfmove_clock = position.halfmove_clock
    clone.fullmove_number = position.fullmove_number
    return clone
end

Position.add_piece = add_piece
Position.remove_piece = remove_piece
Position.move_piece = move_piece

Internal.Position = Position
