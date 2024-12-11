-- _init.lua
--
-- Sets up Lua environment

-- `build.rs` embeds the lua source files in this directory (`src/lua/*.lua`)
-- into a table of functions `_EMBED`:
-- we replace `require` to first check if a file exists in that embedded table

local _require = require
local _LOADED = {}

for k, _v in pairs(_EMBED) do
    print(("> '%s'"):format(k))
end

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

-- luajit vs. lua 5.4 compat
if loadstring then 
    -- lua5.1 / jit
    function loadstring_env(source, name, env)
        local chunk, err = loadstring(source, name)
        if chunk and env then
            setfenv(chunk, env)
        end
        return chunk, err
    end
else 
    -- lua 5.4
    function loadstring_env(source, name, env)
        return load(source, name, "t", env)
    end
end

local files = {
    ["test_file_two.wgsl"] = [[
// This should get emitted!
# function some_macro(arg)
#  return ("vec3f(%s, %s, %s)"):format(arg, arg, arg)
# end
]],
    ["test_file_one.wgsl"] = [[
# include "test_file_two.wgsl"
# THING = true
]],
    ["test_main.wgsl"] = [[
# include "test_file_one.wgsl"
# if THING then
@fragment frag_main(frag_in: VertexOutput) -> vec3f {
    return ${{some_macro("12")}}
}
# else
// THING was not set!
# end
]]
}


local resolver = function(name)
    return assert(files[name], "Missing " .. name)
end

local preprocess = require "preprocess.preprocessor"
local processor = preprocess.Preprocessor(resolver)

processor:include("test_main.wgsl")
local res = processor:get_output()
print("------")
print(res)
