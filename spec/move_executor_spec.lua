local loader = require("spec.support.load_just_chess")
local position_assertions = require("spec.support.position_assertions")

describe("move execution", function()
    local JustChess
    local Internal
    local Move
    local MoveExecutor
    local Position

    before_each(function()
        local namespace = loader.load()
        JustChess = namespace.JustChess
        Internal = namespace.JustChessInternal
        Move = Internal.Move
        MoveExecutor = Internal.MoveExecutor
        Position = Internal.Position
    end)

    local function empty_position(side_to_move)
        local position = Position.new_empty()
        position.side_to_move = side_to_move or JustChess.Color.WHITE
        return position
    end

    local function assert_round_trip(position, move, assertions)
        local expected = Position.clone(position)
        local executor = MoveExecutor.new()

        MoveExecutor.make(executor, position, move)
        assertions(position)
        position_assertions.assert_consistent(position, JustChess, Internal)
        assert.equal(move, MoveExecutor.undo(executor, position))
        position_assertions.assert_consistent(position, JustChess, Internal)
        assert.same(expected, position)
        assert.is_nil(MoveExecutor.undo(executor, position))
    end

    it("makes and unmakes quiet moves and captures", function()
        local position = empty_position()
        Position.set_piece(position, JustChess.Square.E1, JustChess.Piece.WHITE_KING)
        Position.set_piece(position, JustChess.Square.E8, JustChess.Piece.BLACK_KING)
        Position.set_piece(position, JustChess.Square.F3, JustChess.Piece.WHITE_KNIGHT)
        Position.set_piece(position, JustChess.Square.E5, JustChess.Piece.BLACK_PAWN)
        position.halfmove_clock = 9

        local capture = Move.capture(
            JustChess.Square.F3,
            JustChess.Square.E5,
            JustChess.Piece.WHITE_KNIGHT,
            JustChess.Piece.BLACK_PAWN
        )
        assert_round_trip(position, capture, function(changed)
            assert.equal(JustChess.Piece.WHITE_KNIGHT, changed.board[JustChess.Square.E5])
            assert.is_nil(changed.board[JustChess.Square.F3])
            assert.equal(0, changed.halfmove_clock)
            assert.equal(JustChess.Color.BLACK, changed.side_to_move)
            assert.equal(1, changed.fullmove_number)
        end)

        local quiet = Move.quiet(JustChess.Square.F3, JustChess.Square.G5, JustChess.Piece.WHITE_KNIGHT)
        position.en_passant_target = JustChess.Square.E3
        assert_round_trip(position, quiet, function(changed)
            assert.equal(10, changed.halfmove_clock)
            assert.is_nil(changed.en_passant_target)
        end)
    end)

    it("sets en passant targets after double pawn pushes", function()
        local white = Position.new()
        local white_move = Move.double_pawn_push(JustChess.Square.E2, JustChess.Square.E4, JustChess.Piece.WHITE_PAWN)
        assert_round_trip(white, white_move, function(changed)
            assert.equal(JustChess.Square.E3, changed.en_passant_target)
            assert.equal(JustChess.Piece.WHITE_PAWN, changed.board[JustChess.Square.E4])
        end)

        local black = Position.new()
        black.side_to_move = JustChess.Color.BLACK
        local black_move = Move.double_pawn_push(JustChess.Square.E7, JustChess.Square.E5, JustChess.Piece.BLACK_PAWN)
        assert_round_trip(black, black_move, function(changed)
            assert.equal(JustChess.Square.E6, changed.en_passant_target)
            assert.equal(2, changed.fullmove_number)
        end)
    end)

    it("makes and unmakes en passant for both colors", function()
        local cases = {
            {
                color = JustChess.Color.WHITE,
                moving_piece = JustChess.Piece.WHITE_PAWN,
                captured_piece = JustChess.Piece.BLACK_PAWN,
                from = JustChess.Square.D5,
                to = JustChess.Square.E6,
                captured_square = JustChess.Square.E5,
            },
            {
                color = JustChess.Color.BLACK,
                moving_piece = JustChess.Piece.BLACK_PAWN,
                captured_piece = JustChess.Piece.WHITE_PAWN,
                from = JustChess.Square.D4,
                to = JustChess.Square.E3,
                captured_square = JustChess.Square.E4,
            },
        }

        for index = 1, #cases do
            local case = cases[index]
            local position = empty_position(case.color)
            Position.set_piece(position, case.from, case.moving_piece)
            Position.set_piece(position, case.captured_square, case.captured_piece)
            position.en_passant_target = case.to
            local move = Move.en_passant(case.from, case.to, case.color)

            assert_round_trip(position, move, function(changed)
                assert.equal(case.moving_piece, changed.board[case.to])
                assert.is_nil(changed.board[case.captured_square])
                assert.is_nil(changed.en_passant_target)
            end)
        end
    end)

    it("makes and unmakes every promotion for both colors", function()
        local promotions = {
            JustChess.Promotion.KNIGHT,
            JustChess.Promotion.BISHOP,
            JustChess.Promotion.ROOK,
            JustChess.Promotion.QUEEN,
        }
        local cases = {
            {
                color = JustChess.Color.WHITE,
                pawn = JustChess.Piece.WHITE_PAWN,
                captured = JustChess.Piece.BLACK_ROOK,
                from = JustChess.Square.G7,
                to = JustChess.Square.H8,
            },
            {
                color = JustChess.Color.BLACK,
                pawn = JustChess.Piece.BLACK_PAWN,
                captured = JustChess.Piece.WHITE_ROOK,
                from = JustChess.Square.B2,
                to = JustChess.Square.A1,
            },
        }

        for case_index = 1, #cases do
            local case = cases[case_index]
            for promotion_index = 1, #promotions do
                local promotion = promotions[promotion_index]
                for capture = 0, 1 do
                    local position = empty_position(case.color)
                    Position.set_piece(position, case.from, case.pawn)
                    local move
                    if capture == 1 then
                        Position.set_piece(position, case.to, case.captured)
                        move = Move.promote_capture(case.from, case.to, case.pawn, case.captured, promotion)
                    else
                        move = Move.promote(case.from, case.to, case.pawn, promotion)
                    end

                    assert_round_trip(position, move, function(changed)
                        local expected_piece = JustChess.Piece.from_color_kind(
                            case.color,
                            ({
                                [JustChess.Promotion.KNIGHT] = JustChess.PieceKind.KNIGHT,
                                [JustChess.Promotion.BISHOP] = JustChess.PieceKind.BISHOP,
                                [JustChess.Promotion.ROOK] = JustChess.PieceKind.ROOK,
                                [JustChess.Promotion.QUEEN] = JustChess.PieceKind.QUEEN,
                            })[promotion]
                        )
                        assert.equal(expected_piece, changed.board[case.to])
                        assert.is_nil(changed.board[case.from])
                    end)
                end
            end
        end
    end)

    it("makes and unmakes every castle", function()
        local cases = {
            {
                color = JustChess.Color.WHITE,
                king = JustChess.Piece.WHITE_KING,
                rook = JustChess.Piece.WHITE_ROOK,
                king_from = JustChess.Square.E1,
                king_to = JustChess.Square.G1,
                rook_from = JustChess.Square.H1,
                rook_to = JustChess.Square.F1,
                move = function()
                    return Move.short_castle(JustChess.Color.WHITE)
                end,
            },
            {
                color = JustChess.Color.WHITE,
                king = JustChess.Piece.WHITE_KING,
                rook = JustChess.Piece.WHITE_ROOK,
                king_from = JustChess.Square.E1,
                king_to = JustChess.Square.C1,
                rook_from = JustChess.Square.A1,
                rook_to = JustChess.Square.D1,
                move = function()
                    return Move.long_castle(JustChess.Color.WHITE)
                end,
            },
            {
                color = JustChess.Color.BLACK,
                king = JustChess.Piece.BLACK_KING,
                rook = JustChess.Piece.BLACK_ROOK,
                king_from = JustChess.Square.E8,
                king_to = JustChess.Square.G8,
                rook_from = JustChess.Square.H8,
                rook_to = JustChess.Square.F8,
                move = function()
                    return Move.short_castle(JustChess.Color.BLACK)
                end,
            },
            {
                color = JustChess.Color.BLACK,
                king = JustChess.Piece.BLACK_KING,
                rook = JustChess.Piece.BLACK_ROOK,
                king_from = JustChess.Square.E8,
                king_to = JustChess.Square.C8,
                rook_from = JustChess.Square.A8,
                rook_to = JustChess.Square.D8,
                move = function()
                    return Move.long_castle(JustChess.Color.BLACK)
                end,
            },
        }

        for index = 1, #cases do
            local case = cases[index]
            local position = empty_position(case.color)
            Position.set_piece(position, case.king_from, case.king)
            Position.set_piece(position, case.rook_from, case.rook)
            position.castling_rights = JustChess.CastlingRights.ALL

            assert_round_trip(position, case.move(), function(changed)
                assert.equal(case.king, changed.board[case.king_to])
                assert.equal(case.rook, changed.board[case.rook_to])
                assert.is_nil(changed.board[case.king_from])
                assert.is_nil(changed.board[case.rook_from])
            end)
        end
    end)

    it("removes castling rights after king moves, rook moves, and rook captures", function()
        local executor = MoveExecutor.new()
        local position = empty_position()
        Position.set_piece(position, JustChess.Square.E1, JustChess.Piece.WHITE_KING)
        Position.set_piece(position, JustChess.Square.A1, JustChess.Piece.WHITE_ROOK)
        Position.set_piece(position, JustChess.Square.H1, JustChess.Piece.WHITE_ROOK)
        Position.set_piece(position, JustChess.Square.A8, JustChess.Piece.BLACK_ROOK)
        Position.set_piece(position, JustChess.Square.H8, JustChess.Piece.BLACK_ROOK)
        position.castling_rights = JustChess.CastlingRights.ALL

        MoveExecutor.make(
            executor,
            position,
            Move.quiet(JustChess.Square.E1, JustChess.Square.E2, JustChess.Piece.WHITE_KING)
        )
        assert.equal(
            JustChess.CastlingRights.BLACK_KINGSIDE + JustChess.CastlingRights.BLACK_QUEENSIDE,
            position.castling_rights
        )
        MoveExecutor.undo(executor, position)

        MoveExecutor.make(
            executor,
            position,
            Move.capture(
                JustChess.Square.A1,
                JustChess.Square.A8,
                JustChess.Piece.WHITE_ROOK,
                JustChess.Piece.BLACK_ROOK
            )
        )
        assert.equal(
            JustChess.CastlingRights.WHITE_KINGSIDE + JustChess.CastlingRights.BLACK_KINGSIDE,
            position.castling_rights
        )
        MoveExecutor.undo(executor, position)
        position_assertions.assert_consistent(position, JustChess, Internal)
    end)

    it("maintains reusable move history as a stack", function()
        local position = Position.new()
        local expected = Position.clone(position)
        local executor = MoveExecutor.new()
        local first = Move.quiet(JustChess.Square.G1, JustChess.Square.F3, JustChess.Piece.WHITE_KNIGHT)
        local second = Move.quiet(JustChess.Square.G8, JustChess.Square.F6, JustChess.Piece.BLACK_KNIGHT)

        MoveExecutor.make(executor, position, first)
        MoveExecutor.make(executor, position, second)
        assert.equal(2, MoveExecutor.move_count(executor))
        assert.equal(first, MoveExecutor.move_at(executor, 1))
        assert.equal(second, MoveExecutor.move_at(executor, 2))
        assert.equal(second, MoveExecutor.undo(executor, position))
        assert.equal(first, MoveExecutor.undo(executor, position))
        assert.same(expected, position)

        MoveExecutor.make(executor, position, first)
        local first_record = executor.history[1]
        MoveExecutor.undo(executor, position)
        MoveExecutor.make(executor, position, first)
        assert.equal(first_record, executor.history[1])
        MoveExecutor.clear(executor)
        assert.equal(0, MoveExecutor.move_count(executor))
    end)

    it("allocates no garbage after move history is warm", function()
        local position = Position.new()
        local executor = MoveExecutor.new()
        local move = Move.quiet(JustChess.Square.G1, JustChess.Square.F3, JustChess.Piece.WHITE_KNIGHT)

        for _ = 1, 1000 do
            MoveExecutor.make(executor, position, move)
            MoveExecutor.undo(executor, position)
        end
        collectgarbage("collect")
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 10000 do
            MoveExecutor.make(executor, position, move)
            MoveExecutor.undo(executor, position)
        end
        local after = collectgarbage("count")
        collectgarbage("restart")

        assert.equal(before, after)
    end)
end)
