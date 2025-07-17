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
${HEADER}
${VISIBILITY} struct ${NAME} {
${FIELDS}
}
]]

local STRUCT_FILE_TEMPLATE = [[
use bytemuck::{Pod, Zeroable};

${STRUCTS}
]]

---@class RustStructMember
---@field name string
---@field visibility string?
---@field comment string?
---@field derive string?
---@field ty TypeDef?
---@field tyname string
---@field is_padding boolean

---@class RustStruct
---@field name string
---@field derive string?
---@field comment string?
---@field repr string?
---@field visibility string?
---@field header string[]?
---@field fields RustStructMember[]

---@param rstruct RustStruct
---@param template string
---@return string
function m.format_rust_struct(rstruct, template)
    local field_frags = {}
    for _, field in ipairs(rstruct.fields) do
        if field.comment then
            table.insert(field_frags, "    " .. field.comment)
        end
        if field.derive then
            table.insert(field_frags, "    " .. field.derive)
        end
        local vis = field.visibility or "pub"
        table.insert(field_frags, ("    %s %s: %s,"):format(vis, field.name, field.tyname))
    end
    local header = rstruct.header or {}
    if rstruct.comment then
        table.insert(header, rstruct.comment)
    end
    if rstruct.derive then
        table.insert(header, rstruct.derive)
    end
    if rstruct.repr then
        table.insert(header, rstruct.repr)
    end
    return template:with{
        HEADER = table.concat(header, "\n"),
        VISIBILITY = rstruct.visibility or "pub",
        NAME = rstruct.name,
        FIELDS = table.concat(field_frags, "\n"),
    }
end

function m.prepare_struct(options, ty)
    ---@type RustStructMember[]
    local fields = {}
    local function add_field(field)
        if options.field_decorator then
            field = options.field_decorator(field, ty) or field
        end
        table.insert(fields, field)
    end

    local pad_id = 0
    local cur_offset = 0
    local function pad_to(target)
        local npad = target - cur_offset
        if npad <= 0 then return end
        cur_offset = target
        add_field{
            name=("_pad_%s"):format(pad_id),
            tyname=("[u8; %d]"):format(npad),
            is_padding=true
        }
        pad_id = pad_id + 1
    end

    for _, member in ipairs(ty.members) do
        local tysize = member.ty.size
        local offset = member.offset
        pad_to(offset)
        add_field{
            name=member.name,
            ty=member.ty,
            tyname=m.rust_typename(member.ty)
        }
        cur_offset = offset + tysize
    end
    pad_to(ty.size)
    local rstruct = {
        name=ty.name,
        ty=ty,
        derive="#[derive(Copy, Clone, Pod, Zeroable)]",
        repr="#[repr(C)]",
        fields=fields
    }
    if options.struct_decorator then
        rstruct = options.struct_decorator(rstruct) or rstruct
    end
    return rstruct
end

function m.write_struct_defs(options, structs, env)
    if type(options) == 'string' then
        options = {output = options}
    end

    local fileio = require "utils.fileio"
    local frags = {}
    for _, struct in ipairs(structs.structs) do
        local rstruct = m.prepare_struct(options, struct)
        local formatted = m.format_rust_struct(rstruct, options.struct_template or STRUCT_TEMPLATE)
        table.insert(frags, formatted)
        if options.struct_impl then
            local impl = assert(options.struct_impl(rstruct, struct), "struct_impl must return a string!")
            table.insert(frags, impl)
        end
    end
    local struct_str = table.concat(frags, "\n")
    local body = (options.file_template or STRUCT_FILE_TEMPLATE):with{STRUCTS=struct_str}

    fileio.write(options.output:with(env), body)
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