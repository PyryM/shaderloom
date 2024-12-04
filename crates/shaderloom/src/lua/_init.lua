-- _init.lua
--
-- Sets up Lua environment

local _require = require

local _loaded = {}

require = function(name)
    local fn = name:gsub("%.", "/") .. ".lua"
    if _loaded[name] then return _loaded[name] end
    if _p[fn] then 
        print(("Loading '%s'"):format(name))
        _loaded[name] = _p[fn]()
        if _loaded[name] == nil then _loaded[name] = true end
        return _loaded[name]
    end
    print(("Didn't find '%s', trying regular require!"):format(fn))
    return _require(name)
end

-- just test running chunker for now
require("chunker")