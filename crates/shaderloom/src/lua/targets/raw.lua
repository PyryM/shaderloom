-- target.raw
--
-- preprocess and emit shaders as WGSL without any additional
-- analysis / generation (i.e., no auto-bindgroups, etc.)
--
-- also useful for other targets to require for convenience functions

local log = require "log"
local utils = require "utils.common"
local fileio = require "utils.fileio"
local Preprocessor = require("preprocess.preprocessor").Preprocessor
local raw_target = {}
local naga = require "analysis.naga"

function raw_target.preprocess(shaders, include_dirs)
    local resolver = fileio.create_resolver(include_dirs)
    local processed = {}
    for idx, file_info in ipairs(shaders) do
        local pp = Preprocessor(resolver)
        pp:process_source(
            fileio.read(file_info.path),
            file_info.file_name or file_info.path
        )
        local proc = pp:get_output()
        processed[idx] = utils.merge_into({
            name = proc.annotations.name or file_info.file_name or file_info.path or ("shader_" .. idx),
        }, file_info, proc)
    end
    return processed
end

function raw_target.validate(shaders)
    local had_errors = false
    local parsed_shaders = {}
    for idx, shader in ipairs(shaders) do
        local parsed, errs = naga.parse(shader, true)
        if errs then
            log.error(("Error in '${name}' (@'${path}'):??"):with(shader))
            log.multiline(errs)
            log.divider()
            had_errors = true
        else
            parsed_shaders[idx] = parsed
        end
    end
    if had_errors then
        error("Errors in shaders.") 
    else
        log.info("All shaders passed validation.")
    end
    return parsed_shaders
end

function raw_target.emit_bundle(options, shaders, env)
    local outfile = assert(options.output, "Missing .output!"):with(env)

    local shader_template = assert(options.shader_template, "Missing .shader_template!")
    local bundle_template = assert(options.bundle_template, "Missing .bundle_template!")

    local shader_frags = {}
    local params = utils.cascaded_table(env)
    table.sort(shaders, function(a, b)
        return a.name < b.name
    end)
    for idx, shader in ipairs(shaders) do
        params.NAME = shader.name
        params.SOURCE = shader.source
        shader_frags[idx] = shader_template:with(params)
    end
    params = utils.cascaded_table(env)
    params.SHADERS = table.concat(shader_frags, "")

    local bundle_string = bundle_template:with(params)

    fileio.write(outfile, bundle_string)
    log.info("Wrote bundle to", outfile)
end

function raw_target.emit_loose_shaders(options, shaders, env)
    local params = utils.cascaded_table(env)
    local written_names = {}
    local written_count = 0
    for _, shader in ipairs(shaders) do
        params.NAME = shader.name
        params.SOURCE = shader.source
        local outfile = options.output:with(params)
        if written_names[outfile] then
            log.warn(("Multiple shaders map to same output file '%s'"):format(outfile))
        else
            local source = shader.source
            if options.file_template then
                source = options.file_template:with(params)
            end
            fileio.write(outfile, source)
            written_names[outfile] = true
            written_count = written_count + 1
        end
    end
    log.info("Wrote", written_count, "loose shaders.")
end

function raw_target.build(options)
    local shaders = raw_target.preprocess(options.shaders, options.include_dirs)
    local config = options.config
    if config.validate then
        raw_target.validate(shaders)
    end
    if config.bundle then
        raw_target.emit_bundle(config.bundle, shaders, options.env)
    end
    if config.loose_files then
        raw_target.emit_loose_shaders(config.loose_files, shaders, options.env)
    end
end

return raw_target
