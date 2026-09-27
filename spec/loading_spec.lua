local loader = require("spec.support.load_just_chess")
local host_bit = require("bit")

local forbidden_globals = {
    "debug",
    "dofile",
    "io",
    "loadfile",
    "os",
    "package",
    "require",
}

local function global_names()
    local names = {}
    for name in pairs(_G) do
        names[name] = true
    end
    return names
end

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local contents = file:read("*a")
    file:close()
    return contents
end

local function unsigned_operation(operation)
    return function(...)
        local result = operation(...)
        if result < 0 then
            return result + 4294967296
        end
        return result
    end
end

local function unsigned_bit_api()
    local api = {}
    local operations = { "band", "bnot", "bor", "lshift", "rshift" }
    for index = 1, #operations do
        local name = operations[index]
        api[name] = unsigned_operation(host_bit[name])
    end
    return api
end

describe("production loading", function()
    it("loads each core TOC script into one private namespace", function()
        local namespace, report = loader.load()

        assert.same({
            "src/Core/Bootstrap.lua",
            "src/Core/Constants.lua",
            "src/Core/Square.lua",
            "src/Core/Bitboard.lua",
            "src/Core/Move.lua",
            "src/Core/Position.lua",
            "src/Core/MoveExecutor.lua",
            "src/Core/AttackTables.lua",
            "src/Core/Attacks.lua",
            "src/Core/MoveGeneration.lua",
            "src/Core/Game.lua",
        }, report.files)
        assert.is_table(namespace.JustChess)
        assert.is_table(namespace.JustChessInternal)
        assert.equal("@project-version@", namespace.JustChess.VERSION)
    end)

    it("embeds without replacing other private namespace values", function()
        local namespace = { host_value = "preserved" }

        loader.load({
            addon_name = "ExampleAddon",
            namespace = namespace,
        })

        assert.equal("preserved", namespace.host_value)
        assert.is_table(namespace.JustChess)
    end)

    it("does not create Lua globals", function()
        local before = global_names()
        loader.load()
        local after = global_names()

        assert.same(before, after)
    end)

    it("withholds desktop-only globals from production chunks", function()
        local _, report = loader.load()

        for index = 1, #report.environments do
            local environment = report.environments[index]
            for forbidden_index = 1, #forbidden_globals do
                local name = forbidden_globals[forbidden_index]
                assert.is_nil(rawget(environment, name))
                assert.has_error(function()
                    return environment[name]
                end, "production source accessed unavailable global `" .. name .. "`")
            end
        end
    end)

    it("contains no references to unavailable globals", function()
        local _, report = loader.load()

        for index = 1, #report.files do
            local contents = read_file(report.files[index])
            for forbidden_index = 1, #forbidden_globals do
                local name = forbidden_globals[forbidden_index]
                local pattern = "%f[%a_]" .. name .. "%f[^%w_]"
                assert.is_nil(contents:match(pattern), report.files[index] .. " references " .. name)
            end
        end
    end)

    it("supports unsigned bit results used by the beta client", function()
        local namespace = loader.load({ bit = unsigned_bit_api() })
        local Bitboard = namespace.JustChessInternal.Bitboard
        local board = Bitboard.new()

        Bitboard.set(board, 32)
        Bitboard.set(board, 64)
        assert.equal(2147483648, board.lo)
        assert.equal(2147483648, board.hi)
        assert.equal(2, Bitboard.count(board))

        local game = namespace.JustChess.new_game()
        game._position.side_to_move = namespace.JustChess.Color.BLACK
        assert.equal(20, #game:get_legal_moves())
    end)
end)
