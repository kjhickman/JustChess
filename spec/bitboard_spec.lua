local bit = require("bit")
local loader = require("spec.support.load_just_chess")

describe("bitboards", function()
    local Bitboard

    before_each(function()
        local namespace = loader.load()
        Bitboard = namespace.JustChessInternal.Bitboard
    end)

    it("sets, tests, clears, and moves all 64 squares", function()
        local board = Bitboard.new()
        assert.equal(0, Bitboard.count(board))

        for square = 1, 64 do
            Bitboard.set(board, square)
            assert.is_true(Bitboard.contains(board, square))
        end

        assert.equal(64, Bitboard.count(board))
        for square = 1, 64 do
            Bitboard.unset(board, square)
            assert.is_false(Bitboard.contains(board, square))
        end
        assert.equal(0, Bitboard.count(board))

        for square = 1, 63 do
            Bitboard.clear(board)
            Bitboard.set(board, square)
            Bitboard.move(board, square, square + 1)
            assert.is_false(Bitboard.contains(board, square))
            assert.is_true(Bitboard.contains(board, square + 1))
        end
    end)

    it("copies without aliasing", function()
        local source = Bitboard.new()
        local output = Bitboard.new()
        Bitboard.set(source, 17)
        Bitboard.copy_into(output, source)

        assert.equal(source.lo, output.lo)
        assert.equal(source.hi, output.hi)
        Bitboard.set(output, 18)
        assert.equal(1, Bitboard.count(source))
    end)

    it("uses the host bit library's word representation", function()
        local board = Bitboard.new()
        Bitboard.set(board, 32)
        assert.equal(bit.lshift(1, 31), board.lo)
        Bitboard.clear(board)
        Bitboard.set(board, 64)
        assert.equal(bit.lshift(1, 31), board.hi)
    end)
end)
