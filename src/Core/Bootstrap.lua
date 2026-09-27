local addon_name, addon = ...

assert(type(addon_name) == "string", "JustChess requires an addon name")
assert(type(addon) == "table", "JustChess requires an addon private namespace")
assert(addon.JustChess == nil, "JustChess is already loaded")

addon.JustChess = { VERSION = "@project-version@" }
addon.JustChessInternal = {}
