-- targets.rust.wgpu
--
--

local utils = require "utils.common"

local m = {}

local RUST_SCALARS = {
    f32 = "f32",
    f16 = "f16",
    u32 = "u32",
    i32 = "i32",
    bool = "u8", -- ??
}

function m.rust_typename(ty)
    local kind = ty.kind
    if kind == "scalar" then
        return RUST_SCALARS[ty.name]
    elseif kind == "vector" or kind == "array" then
        local count = assert(ty.count, "array dtypes must have fixed size!")
        return ("[%s; %d]"):format(m.rust_typename(ty.inner), count)
    elseif kind == "matrix" then
        return ("[%s; %d]"):format(
            m.rust_typename(ty.inner),
            ty.rows * ty.cols
        )
    elseif kind == "atomic" then
        return m.rust_typename(ty.inner)
    elseif kind == "struct" then
        return ty.name
    else
        error("Could not create dtype for " .. kind)
    end
end

local STRUCT_TEMPLATE = [[
#[derive(Copy, Clone, Pod, Zeroable)]
#[repr(C)]
pub struct ${NAME} {
${FIELDS}
}
]]

local STRUCT_FILE_TEMPLATE = [[
use bytemuck::{Pod, Zeroable};

${STRUCTS}
]]

function m.emit_struct_def(ty, template)
    local fields = {}
    local cur_offset = 0
    local pad_id = 0
    for _, member in ipairs(ty.members) do
        local name = member.name
        local tyname = m.rust_typename(member.ty)
        local tysize = member.ty.size
        local offset = member.offset
        if cur_offset < offset then
            local npad = offset - cur_offset
            table.insert(fields, ("    pub _pad_%s: [u8; %d],"):format(pad_id, npad))
            pad_id = pad_id + 1
        end
        table.insert(fields, ("    pub %s: %s,"):format(name, tyname))
        cur_offset = offset + tysize
    end
    if cur_offset < ty.size then
        local npad = ty.size - cur_offset
        table.insert(fields, ("    pub _pad_%s: [u8; %d],"):format(pad_id, npad))
    end
    return template:with{
        NAME = ty.name,
        FIELDS = table.concat(fields, "\n"),
    }
end

function m.write_struct_defs(options, structs, env)
    if type(options) == 'string' then
        options = {output = options}
    end

    local fileio = require "utils.fileio"
    local frags = {}
    for _, struct in ipairs(structs.structs) do
        table.insert(frags, m.emit_struct_def(struct, options.struct_template or STRUCT_TEMPLATE))
    end
    local struct_str = table.concat(frags, "\n")
    local body = (options.file_template or STRUCT_FILE_TEMPLATE):with{STRUCTS=struct_str}

    fileio.write(options.output, body)
end

function m.build(options)
    local raw = require "targets.raw"
    local unify = require "analysis.unify"
    local shaders = raw.preprocess(options.shaders, options.include_dirs)
    local config = options.config
    local parsed
    if config.validate or config.struct_definitions then
        parsed = raw.validate(shaders)
    end
    if config.struct_definitions then
        local structs = unify.unify_host_shared_structs(parsed)
        m.write_struct_defs(config.struct_definitions, structs, options.env)
    end
    if config.bundle then
        raw.emit_bundle(config.bundle, shaders, options.env)
    end
    if config.loose_files then
        raw.emit_loose_shaders(config.loose_files, shaders, options.env)
    end
end

local tests = {}
m._tests = tests

return m