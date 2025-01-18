-- _init.lua
--
-- Sets up Lua environment

-- `build.rs` embeds the lua source files in this directory (`src/lua/*.lua`)
-- into a table of functions `_EMBED`:
-- we replace `require` to first check if a file exists in that embedded table

local _require = require
local _LOADED = {}

_EMBED["_termcolor.lua"]()

print = function(...)
    loom:print(table.concat({...}, " "))
end

require = function(name)
    local fn = name:gsub("%.", "/") .. ".lua"
    if _LOADED[name] then return _LOADED[name] end
    if _EMBED[fn] then
        --print(("Loading '%s'"):format(name):blue())
        _LOADED[name] = _EMBED[fn]()
        if _LOADED[name] == nil then _LOADED[name] = true end
        return _LOADED[name]
    end
    print(("Didn't find '%s', trying regular require!"):format(fn):yellow())
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

-- luajit vs 5.4 again
unpack = unpack or table.unpack 

local function bundle_to_source(location)
    local prev = 0
    for _, loc in ipairs(_SOURCE_LOCATIONS) do
        local linepos, name = loc[1], loc[2]
        if linepos > location then
            return name .. ":" .. (location - prev - 1)
        end
        prev = linepos
    end
    return "BUNDLE?:" .. location
end

local function remap_trace(trace)
    -- remap bundle locations like <BUNDLE>:508
    if type(trace) ~= 'string' then trace = tostring(trace) end
    return trace:gsub("<BUNDLE>:(%d*)", function(m)
        return bundle_to_source(tonumber(m))
    end)
end

local function wrapped_call(f, ...)
    local happy, err = xpcall(f, debug.traceback, ...)
    if happy then
        return true, err
    else
        return false, remap_trace(err)
    end
end

local function assert_wrapped(f, ...)
    local happy, err_or_result = wrapped_call(f, ...)
    if not happy then error(err_or_result) end
    return err_or_result
end

-- main entry point from rust side
function _run_module(name)
    local module = assert(require(name), "No module named " .. name)
    if type(module) == "function" then
        return assert_wrapped(module)
    elseif module.main then
        return assert_wrapped(module.main, module)
    else
        print("Note: module", name, "doesn't have a .main!")
    end
end

-- test entry point from rust side
function _run_tests(module_name)
    local module = assert(require(module_name), "No module named " .. module_name)
    local tests
    if type(module) == 'function' then
        tests = {[module_name] = module}
    elseif module._tests then
        tests = module._tests
    end
    if not tests then
        print("INFO: No tests for module " .. module_name)
        return
    end
    local test_names = {}
    for k, _ in pairs(tests) do table.insert(test_names, k) end
    table.sort(test_names)
    local had_errors = 0
    for _, name in ipairs(test_names) do
        local happy, err = wrapped_call(tests[name])
        if not happy then
            print(("FAIL %s: %s"):format(name, err):red())
            had_errors = had_errors + 1
        end
    end
    if had_errors > 0 then error("Tests failed: " .. had_errors) end
end

CONFIG = {}

function _update_config(vals)
    require("utils.common").merge_into(CONFIG, vals)
end

-- install string utilities onto strings
require("utils.stringmanip").install()

-- disable global modification
setmetatable(_G, {
    __index = function(t, k)
        error("Tried to access nil global " .. k)
    end,
    __newindex = function(t, k, v)
        error("Tried to assign to global " .. k)
    end
})