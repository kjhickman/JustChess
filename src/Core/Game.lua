local _, addon = ...

local JustChess = assert(addon.JustChess, "JustChess bootstrap must load first")
local Internal = assert(addon.JustChessInternal, "JustChess bootstrap must load first")
local Attacks = assert(Internal.Attacks, "JustChess attacks must load first")
local Move = assert(Internal.Move, "JustChess move must load first")
local MoveExecutor = assert(Internal.MoveExecutor, "JustChess move executor must load first")
local MoveGeneration = assert(Internal.MoveGeneration, "JustChess move generation must load first")
local Position = assert(Internal.Position, "JustChess position must load first")
local Promotion = assert(JustChess.Promotion, "JustChess constants must load first")
local Square = assert(JustChess.Square, "JustChess constants must load first")

local Game = {}
Game.__index = Game

local valid_promotion = {
    [Promotion.KNIGHT] = true,
    [Promotion.BISHOP] = true,
    [Promotion.ROOK] = true,
    [Promotion.QUEEN] = true,
}

local function find_legal_move(game, from, to, promotion)
    if not Square.is_valid(from) then
        return nil, "invalid source square"
    end
    if not Square.is_valid(to) then
        return nil, "invalid destination square"
    end
    if promotion ~= nil and not valid_promotion[promotion] then
        return nil, "invalid promotion"
    end

    local moves = game._move_buffer
    local count = Game.write_legal_moves(game, moves, from)
    local promotion_required = false
    for index = 1, count do
        local move = moves[index]
        if Move.to_square(move) == to then
            local move_promotion = Move.promotion(move)
            if move_promotion == Promotion.NONE then
                if promotion == nil then
                    return move
                end
            elseif promotion == move_promotion then
                return move
            elseif promotion == nil then
                promotion_required = true
            end
        end
    end

    if promotion_required then
        return nil, "promotion is required"
    end
    return nil, "move is not legal"
end

function Game.write_legal_moves(game, output, from_square)
    assert(type(output) == "table", "output must be a table")
    if from_square ~= nil then
        assert(Square.is_valid(from_square), "invalid source square")
    end

    local count = MoveGeneration.write_legal_moves(game._position, output, game._generation_context)
    if from_square == nil then
        return count
    end

    local filtered_count = 0
    for index = 1, count do
        local move = output[index]
        if Move.from_square(move) == from_square then
            filtered_count = filtered_count + 1
            output[filtered_count] = move
        end
    end
    return filtered_count
end

function Game.get_legal_moves(game, from_square)
    local moves = {}
    local count = Game.write_legal_moves(game, moves, from_square)
    for index = count + 1, #moves do
        moves[index] = nil
    end
    return moves
end

function Game.find_legal_move(game, from, to, promotion)
    return find_legal_move(game, from, to, promotion)
end

function Game.try_make_move(game, from, to, promotion)
    local move, move_error = find_legal_move(game, from, to, promotion)
    if move == nil then
        return nil, move_error
    end

    MoveExecutor.make(game._executor, game._position, move)
    return true
end

function Game.make_move_unchecked(game, move)
    assert(type(move) == "number", "move must be a packed move")
    MoveExecutor.make(game._executor, game._position, move)
end

function Game.undo_move(game)
    return MoveExecutor.undo(game._executor, game._position)
end

function Game.reset(game)
    Position.reset(game._position)
    MoveExecutor.clear(game._executor)
end

function Game.piece_at(game, square)
    return Position.piece_at(game._position, square)
end

function Game.side_to_move(game)
    return game._position.side_to_move
end

function Game.is_in_check(game)
    return Attacks.is_in_check(game._position, game._position.side_to_move)
end

function Game.status(game)
    local in_check = Game.is_in_check(game)
    local count = MoveGeneration.write_legal_moves(game._position, game._move_buffer, game._generation_context)
    if count == 0 then
        return in_check and "checkmate" or "stalemate"
    end
    return in_check and "check" or "ongoing"
end

function Game.move_count(game)
    return MoveExecutor.move_count(game._executor)
end

function Game.move_at(game, index)
    return MoveExecutor.move_at(game._executor, index)
end

function Game.new(position)
    return setmetatable({
        _position = position or Position.new(),
        _executor = MoveExecutor.new(),
        _generation_context = MoveGeneration.new_context(),
        _move_buffer = {},
    }, Game)
end

function JustChess.new_game()
    return Game.new()
end

Internal.Game = Game
