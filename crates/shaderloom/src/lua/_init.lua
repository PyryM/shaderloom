-- _init.lua
--
-- Sets up Lua environment

-- `build.rs` embeds the lua source files in this directory (`src/lua/*.lua`)
-- into a table of functions `_EMBED`:
-- we replace `require` to first check if a file exists in that embedded table

local _require = require
local _LOADED = {}

print = function(...)
    loom:print(table.concat({...}, " "))
end

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

-- main entry point from rust side
function _run_module(name)
    local module = assert(require(name), "No module named " .. name)
    if type(module) == "function" then
        return module()
    elseif module.main then
        return module:main()
    else
        print("Note: module", name, "doesn't have a .main!")
    end
end

-- test entry point from rust side
function _run_tests(module_name)
    local module = assert(require(module_name), "No module named " .. module_name)
    local tests = module._tests
    if not tests then
        print("INFO: No tests for module " .. module_name)
        return
    end
    local test_names = {}
    for k, _ in pairs(tests) do table.insert(test_names, k) end
    table.sort(test_names)
    local had_errors = 0
    for _, name in ipairs(test_names) do
        local happy, err = pcall(tests[name])
        if not happy then
            print(("FAIL %s: %s"):format(name, err))
            had_errors = had_errors + 1
        end
    end
    if had_errors > 0 then error("Tests failed: " .. had_errors) end
end
