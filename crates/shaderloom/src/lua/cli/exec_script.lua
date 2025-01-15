-- cli.exec_script
--
-- main entry point for running a user-supplied build script

local function make_proxy_env()
    return setmetatable({}, {
        __index = _G
    })
end

local function read_string(fn)
    local f = assert(io.open(fn))
    local data = assert(f:read("a"))
    f:close()
    return data
end

local function main()
    local path = assert(
        CONFIG.ABSSCRIPTPATH or CONFIG.SCRIPTPATH, 
        "Mising input script filename!"
    )
    local script = read_string(path)
    local defers = {}
    local env = make_proxy_env()
    function env.defer(func) table.insert(defers, func) end
    function env.use(name) 
        local module = require(name)
        local use = assert(
            module.use, 
            "Module [" .. name .. "] cannot be required with 'use'"
        )
        return use(env)
    end

    assert(loadstring_env(script, path, env))()
    for _, deferred in ipairs(defers) do
        deferred()
    end
end

return {main = main}