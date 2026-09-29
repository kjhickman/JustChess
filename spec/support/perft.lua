local M = {}

local function visit(runner, position, remaining)
    if remaining == 0 then
        return 1
    end
    if remaining == 1 then
        return runner.Internal.MoveGeneration.write_legal_moves(position, nil, runner.contexts[remaining])
    end

    local moves = runner.buffers[remaining]
    local count = runner.Internal.MoveGeneration.write_legal_moves(position, moves, runner.contexts[remaining])

    local nodes = 0
    for index = 1, count do
        runner.Internal.MoveExecutor.make(runner.executor, position, moves[index])
        nodes = nodes + visit(runner, position, remaining - 1)
        runner.Internal.MoveExecutor.undo(runner.executor, position)
    end
    return nodes
end

function M.new(Internal, maximum_depth)
    local runner = {
        Internal = Internal,
        buffers = {},
        contexts = {},
        executor = Internal.MoveExecutor.new(),
    }
    for depth = 1, maximum_depth do
        runner.buffers[depth] = {}
        runner.contexts[depth] = Internal.MoveGeneration.new_context()
    end
    return runner
end

function M.count(runner, position, depth)
    assert(depth >= 0 and depth == math.floor(depth), "depth must be a non-negative integer")
    assert(runner.executor.count == 0, "perft executor history must be empty")
    local nodes = visit(runner, position, depth)
    assert(runner.executor.count == 0, "perft did not restore move history")
    return nodes
end

return M
