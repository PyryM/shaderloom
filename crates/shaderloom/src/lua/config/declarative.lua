-- config.declarative
--
-- sets up a 'declarative' configuration file style

local merge_into = require("utils.common").merge_into
local curry = require("utils.common").curry
local log = require "log"

local function use(env)
    local target = nil
    local target_config = {}
    local shaders = {}
    local include_dirs = {}

    -- register all the funcs into env as globals
    env.target = curry(2, function(name, config)
        target = name
        merge_into(target_config, config)
    end)

    function env.add_shaders(patt)
        if type(patt) == 'table' then
            for _, item in ipairs(patt) do
                env.add_shaders(item)
            end
        elseif type(patt) == 'string' then
            patt = patt:with(env)
            for _, item in ipairs(loom:glob(patt)) do
                if item.is_file then
                    table.insert(shaders, item)
                end
            end
        else
            error(("Invalid shader specifier [%s]: %s"):format(
                type(patt), tostring(patt)
            ))
        end
    end

    function env.include_dirs(patt)
        if type(patt) == 'table' then
            for _, item in ipairs(patt) do
                env.include_dirs(patt)
            end
        elseif type(patt) == 'string' then
            patt = patt:with(env)
            local match_count = 0
            for _, item in ipairs(loom:glob(patt)) do
                if item.is_dir then
                    table.insert(include_dirs, item.path)
                    match_count = match_count + 1
                end
            end
            if match_count == 0 then
                log.warn(("include pattern '%s' matched no directories"):format(patt))
            end
        else
            error("Invalid include dir? " .. tostring(patt))
        end
    end

    local function build()
        assert(target, "No target has been set!")
        target = require("targets." .. target)
        target.build{
            config = target_config,
            shaders = shaders,
            include_dirs = include_dirs,
            env = env
        }
    end

    -- defer actually running build stuff until after config script
    -- has finished.
    env.defer(build)
end

return {use = use}