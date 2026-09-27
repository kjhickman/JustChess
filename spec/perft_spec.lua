local fen = require("spec.support.fen")
local fixture = require("spec.fixtures.perft")
local loader = require("spec.support.load_just_chess")
local perft = require("spec.support.perft")

local maximum_depth = tonumber(os.getenv("JUSTCHESS_PERFT_DEPTH") or "3")
assert(maximum_depth and maximum_depth >= 1 and maximum_depth <= 6, "JUSTCHESS_PERFT_DEPTH must be between 1 and 6")

local shard_count = tonumber(os.getenv("JUSTCHESS_PERFT_SHARDS") or "1")
local shard_index = tonumber(os.getenv("JUSTCHESS_PERFT_SHARD") or "1")
assert(
    shard_count and shard_count >= 1 and shard_count == math.floor(shard_count),
    "JUSTCHESS_PERFT_SHARDS must be a positive integer"
)
assert(
    shard_index and shard_index >= 1 and shard_index <= shard_count and shard_index == math.floor(shard_index),
    "JUSTCHESS_PERFT_SHARD must be an integer between 1 and JUSTCHESS_PERFT_SHARDS"
)

local expected_case_counts = { 126, 252, 378, 507, 637, 764 }
local expected_node_sums = { 1408, 22542, 508717, 15303314, 515831066, 5620139178 }

describe("perft corpus", function()
    local namespace
    local Internal
    local runner
    local enabled_cases = {}

    for position_index = 1, #fixture do
        local entry = fixture[position_index]
        for count_index = 1, #entry.counts do
            local case = entry.counts[count_index]
            if case[1] <= maximum_depth then
                enabled_cases[#enabled_cases + 1] = {
                    id = entry.id,
                    fen = entry.fen,
                    depth = case[1],
                    expected_nodes = case[2],
                }
            end
        end
    end

    table.sort(enabled_cases, function(a, b)
        if a.expected_nodes ~= b.expected_nodes then
            return a.expected_nodes > b.expected_nodes
        end
        if a.id ~= b.id then
            return a.id < b.id
        end
        return a.depth < b.depth
    end)

    local shard_loads = {}
    for shard = 1, shard_count do
        shard_loads[shard] = 0
    end
    for case_index = 1, #enabled_cases do
        local case = enabled_cases[case_index]
        local lightest_shard = 1
        for shard = 2, shard_count do
            if shard_loads[shard] < shard_loads[lightest_shard] then
                lightest_shard = shard
            end
        end
        case.shard = lightest_shard
        shard_loads[lightest_shard] = shard_loads[lightest_shard] + case.expected_nodes
    end

    table.sort(enabled_cases, function(a, b)
        if a.id ~= b.id then
            return a.id < b.id
        end
        return a.depth < b.depth
    end)

    setup(function()
        namespace = loader.load()
        Internal = namespace.JustChessInternal
        runner = perft.new(Internal, maximum_depth)
    end)

    it("contains every source position and expected count", function()
        assert.equal(130, #fixture)

        local case_counts = { 0, 0, 0, 0, 0, 0 }
        local node_sums = { 0, 0, 0, 0, 0, 0 }
        for position_index = 1, #fixture do
            local entry = fixture[position_index]
            assert.equal(position_index, entry.id)
            for count_index = 1, #entry.counts do
                local case = entry.counts[count_index]
                assert.is_true(case[1] >= 1 and case[1] <= 6)
                assert.is_true(case[2] >= 0)
                for depth_limit = case[1], 6 do
                    case_counts[depth_limit] = case_counts[depth_limit] + 1
                    node_sums[depth_limit] = node_sums[depth_limit] + case[2]
                end
            end
        end

        assert.same(expected_case_counts, case_counts)
        assert.same(expected_node_sums, node_sums)
        assert.equal(expected_case_counts[maximum_depth], #enabled_cases)
    end)

    local function add_case(case)
        if case.shard ~= shard_index then
            return
        end

        it(("matches position %03d at depth %d"):format(case.id, case.depth), function()
            local position = fen.parse(case.fen, namespace)
            local expected_position = Internal.Position.clone(position)

            assert.equal(case.expected_nodes, perft.count(runner, position, case.depth))
            assert.same(expected_position, position)
        end)
    end

    for case_index = 1, #enabled_cases do
        add_case(enabled_cases[case_index])
    end
end)
