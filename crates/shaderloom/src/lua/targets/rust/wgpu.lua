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
pub struct ${name} {
${fields}
}
]]

function m.emit_struct_def(ty)
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
    return STRUCT_TEMPLATE:with{
        name = ty.name,
        fields = table.concat(fields, "\n"),
    }
end

function m.build(options)
    local raw = require "targets.raw"
    local unify = require "analysis.unify"
    local fileio = require "utils.fileio"
    local shaders = raw.preprocess(options.shaders, options.include_dirs)
    local params = utils.cascaded_table(options.env)
    local config = options.config
    local parsed = raw.validate(shaders)
    local structs = unify.unify_host_shared_structs(parsed)
    local bundle_filename = assert(config.bundle, "Must specify .bundle!"):with(params)
    local frags = {"use bytemuck::{Pod, Zeroable};", ""}
    for _, struct in ipairs(structs.structs) do
        table.insert(frags, m.emit_struct_def(struct))
    end
    fileio.write(bundle_filename, table.concat(frags, "\n"))
end

local tests = {}
m._tests = tests

return m