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

print(SCRIPTDIR)
print(ABSSCRIPTDIR)
print(SCRIPTPATH)
print(ABSSCRIPTPATH)

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
]],
    ["collatz.wgsl"] = [[
struct PrimeIndices {
    data: array<u32>
} // this is used as both input and output for convenience

@group(0) @binding(0)
var<storage,read_write> v_indices: PrimeIndices;

// The Collatz Conjecture states that for any integer n:
// If n is even, n = n/2
// If n is odd, n = 3n+1
// And repeat this process for each new n, you will always eventually reach 1.
// Though the conjecture has not been proven, no counterexample has ever been found.
// This function returns how many times this recurrence needs to be applied to reach 1.
fn collatz_iterations(n_base: u32) -> u32 {
    var n = n_base;
    var i: u32 = 0u;
    while n > 1u {
        if n % 2u == 0u {
            n = n / 2u;
        }
        else {
            n = 3u * n + 1u;
        }
        i = i + 1u;
    }
    return i;
}

@compute @workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    v_indices.data[global_id.x] = collatz_iterations(v_indices.data[global_id.x]);
}
]]
}

local function format_primitive(val)
    local vt = type(val)
    if vt == "string" then
        return '[string] "' .. val .. '"'
    elseif vt == "userdata" and val == null then
        return '[null]'
    else
        return ("[%s] %s"):format(vt, tostring(val))
    end
end

local function _deep_print(printer, indent, key, val)
    if type(val) ~= "table" then
        printer(indent, ("%s = %s,"):format(key, format_primitive(val)))
        return
    end
    printer(indent, ("%s = {"):format(key))
    local max_idx_printed = #val
    for idx = 1, max_idx_printed do
        _deep_print(printer, indent+1, idx, val[idx])
    end
    for k, v in pairs(val) do
        if type(k) ~= "number" or k <= 0 or k > max_idx_printed then
            _deep_print(printer, indent+1, k, v)
        end
    end
    printer(indent, "},")
end

local function deep_print(v)
    local function printer(indent, v)
        print((" "):rep(indent*4) .. tostring(v))
    end
    _deep_print(printer, 0, "VAL", v)
end

local resolver = function(name)
    return assert(files[name], "Missing " .. name)
end

local preprocess = require "preprocess.preprocessor"
local processor = preprocess.Preprocessor(resolver)

processor:include("test_main.wgsl")
local res = processor:get_output()
print("------")
print(res)

processor:clear()
processor:include("collatz.wgsl")
local src = processor:get_output()
local parsed = _naga_parse(src)
deep_print(parsed)
