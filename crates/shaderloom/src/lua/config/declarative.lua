-- config.declarative
--
-- sets up a 'declarative' configuration file style

local merge_into = require("utils.common").merge_into

local function use(env)
    local target = nil
    local target_config = {}
    local shaders = {}

    -- register all the funcs into env as globals
    function env.target(name, config)
        target = require("target." .. name)
        if config then merge_into(target_config, config) end
    end

    function env.target_settings(config)
        merge_into(target_config, config)
    end

    function env.add_shaders(patt, options)
        -- todo?
    end

    local function build()
        assert(target, "No target has been set!")
        target.build(target_config, shaders)
    end

    -- defer actually running build stuff until after config script
    -- has finished.
    env.defer(build)
end

return {use = use}