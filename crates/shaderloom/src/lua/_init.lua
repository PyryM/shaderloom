-- _init.lua
--
-- Sets up Lua environment

-- `build.rs` embeds the lua source files in this directory (`src/lua/*.lua`)
-- into a table of functions `_EMBED`:
-- we replace `require` to first check if a file exists in that embedded table

local _require = require
local _LOADED = {}

require = function(name)
    local fn = name:gsub("%.", "/") .. ".lua"
    if _LOADED[name] then return _LOADED[name] end
    if _EMBED[fn] then 
        print(("Loading '%s'"):format(name))
        _LOADED[name] = _EMBED[fn]()
        if _LOADED[name] == nil then _LOADED[name] = true end
        return _LOADED[name]
    end
    print(("Didn't find '%s', trying regular require!"):format(fn))
    return _require(name)
end

-- just test running chunker for now
require("chunker")