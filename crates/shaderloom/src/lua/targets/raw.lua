-- target.raw
--
-- preprocess and emit shaders as WGSL without any additional
-- analysis / generation (i.e., no auto-bindgroups, etc.)
--
-- also useful for other targets to require for convenience functions

local fileio = require "utils.fileio"
local Preprocessor = require("preprocess.preprocessor").Preprocessor
local raw_target = {}

function raw_target.preprocess(shaders, include_dirs)
    local resolver = fileio.create_resolver(include_dirs)
    local processed = {}
    for idx, file_info in ipairs(shaders) do
        local pp = Preprocessor(resolver)
        pp:process_source(
            fileio.read(file_info.path),
            file_info.file_name or file_info.path
        )
        local out_source, annotations = pp:get_output()
        processed[idx] = {
            source = out_source,
            annotations = annotations,
            file_info = file_info,
            name = annotations.name or file_info.file_name or file_info.path or ("shader_" .. idx)
        }
    end
    return processed
end

function raw_target.create_bundle(options, shaders)
    local shader_template = assert(options.shader_template, "Missing .shader_template!")
    local bundle_template = assert(options.bundle_template, "Missing .bundle_template!")

    local shader_frags = {}
    table.sort(shaders, function(a, b)
        return a.name < b.name
    end)
    for idx, shader in ipairs(shaders) do
        shader_frags[idx] = shader_template:with{
            NAME = shader.name,
            SOURCE = shader.source
        }
    end
    return bundle_template:with{
        SHADERS = table.concat(shader_frags, "")
    }
end

function raw_target.build(options)
    local shaders = raw_target.preprocess(options.shaders, options.include_dirs)
    local config = options.config
    if config.bundle then
        local bundle = raw_target.create_bundle(config.bundle, shaders)
        fileio.write(config.output:with(CONFIG), bundle)
    else
        error("Only bundle supported ATM!")
    end
end

return raw_target
