local loader = require("spec.support.load_just_chess")

describe("squares", function()
    local Square

    before_each(function()
        Square = loader.load().JustChess.Square
    end)

    it("numbers every square from a1 through h8", function()
        for rank = 1, 8 do
            for file = 1, 8 do
                local square = (rank - 1) * 8 + file
                local name = string.char(64 + file) .. rank

                assert.equal(square, Square[name])
                assert.equal(square, Square.from_rank_file(rank, file))
                assert.equal(square, Square.from_name(string.lower(name)))
                assert.equal(rank, Square.rank(square))
                assert.equal(file, Square.file(square))
                assert.equal(string.lower(name), Square.name(square))
                assert.is_true(Square.is_valid(square))
            end
        end
    end)

    it("rejects invalid squares", function()
        local invalid_squares = { -1, 0, 1.5, 65, "a1" }
        for index = 1, #invalid_squares do
            assert.is_false(Square.is_valid(invalid_squares[index]))
        end

        assert.is_nil(Square.from_rank_file(0, 1))
        assert.is_nil(Square.from_rank_file(1, 9))
        assert.is_nil(Square.from_name("a0"))
        assert.is_nil(Square.from_name("i1"))
        assert.is_nil(Square.from_name("A1"))
        assert.is_nil(Square.from_name("a10"))
        assert.has_error(function()
            Square.rank(0)
        end, "invalid square")
    end)
end)
