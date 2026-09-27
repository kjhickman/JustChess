local host_bit = require("bit")

local M = {}

local allowed_globals = {
    _VERSION = _VERSION,
    assert = assert,
    error = error,
    getmetatable = getmetatable,
    ipairs = ipairs,
    math = math,
    next = next,
    pairs = pairs,
    pcall = pcall,
    rawequal = rawequal,
    rawget = rawget,
    rawset = rawset,
    select = select,
    setmetatable = setmetatable,
    string = string,
    table = table,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    unpack = unpack,
    xpcall = xpcall,
}

local function read_file(path)
    local file, open_error = io.open(path, "r")
    if not file then
        error(open_error)
    end

    local contents = file:read("*a")
    file:close()
    return contents
end

local function new_environment(bit_api)
    local environment = {}
    for name, value in pairs(allowed_globals) do
        environment[name] = value
    end
    environment.bit = bit_api

    return setmetatable(environment, {
        __index = function(_, name)
            error("production source accessed unavailable global `" .. tostring(name) .. "`", 2)
        end,
        __newindex = function(_, name)
            error("production source wrote global `" .. tostring(name) .. "`", 2)
        end,
    })
end

function M.load(options)
    options = options or {}

    local addon_name = options.addon_name or "JustChess"
    local namespace = options.namespace or {}
    local bit_api = options.bit or host_bit
    local toc = read_file("JustChess.toc")
    local report = {
        environments = {},
        files = {},
    }

    for line in toc:gmatch("[^\r\n]+") do
        local file_name = line:match("^%s*([^#].-%.lua)%s*$")
        if file_name ~= nil then
            file_name = file_name:gsub("\\", "/")
        end

        if file_name ~= nil and file_name:match("^src/Core/") then
            local chunk, load_error = loadfile(file_name)
            if not chunk then
                error(load_error)
            end

            local environment = new_environment(bit_api)
            setfenv(chunk, environment)
            chunk(addon_name, namespace)

            local index = #report.files + 1
            report.files[index] = file_name
            report.environments[index] = environment
        end
    end

    if #report.files == 0 then
        error("JustChess TOC contains no core scripts")
    end

    return namespace, report
end

return M
