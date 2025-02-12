-- targets.python.xgpu
--
--

local utils = require "utils.common"

local m = {}

local NUMPY_SCALARS = {
    f32 = "np.float32",
    f16 = "np.float16",
    u32 = "np.uint32",
    i32 = "np.int32",
    bool = "np.bool_", -- ??
}

function m.numpy_dtype(ty)
    local kind = ty.kind
    if kind == "scalar" then
        return NUMPY_SCALARS[ty.name]
    elseif kind == "vector" or kind == "array" then
        local count = assert(ty.count, "array dtypes must have fixed size!")
        return ("np.dtype((%s, %d))"):format(m.numpy_dtype(ty.inner), count)
    elseif kind == "matrix" then
        return ("np.dtype((%s, (%d, %d)))"):format(
            m.numpy_dtype(ty.inner),
            ty.rows,
            ty.cols
        )
    elseif kind == "atomic" then
        return m.numpy_dtype(ty.inner)
    elseif kind == "struct" then
        return ty.name:upper() .. "_DTYPE"
    else
        error("Could not create dtype for " .. kind)
    end
end

local STRUCT_TEMPLATE = [[
${name} = np.dtype({
    "names": ${fields},
    "formats": ${formats},
    "offsets": ${offsets},
    "itemsize": ${itemsize}
})
]]

local function quoted(v)
    return '"' .. v .. '"'
end

local function pylist(items, quote_items)
    if quote_items then 
        items = utils.map(items, quoted)
    end
    return "[" .. table.concat(items, ", ") .. "]"
end

function m.emit_numpy_struct_dtype(ty)
    local field_names = {}
    local formats = {}
    local offsets = {}
    for idx, member in ipairs(ty.members) do
        field_names[idx] = member.name
        formats[idx] = m.numpy_dtype(member.ty)
        offsets[idx] = member.offset
    end
    return STRUCT_TEMPLATE:with{
        name = ty.name:upper() .. "_DTYPE",
        fields = pylist(field_names, true),
        formats = pylist(formats),
        offsets = pylist(offsets),
        itemsize = ty.size
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
    local frags = {}
    for _, struct in ipairs(structs.structs) do
        local dtype = m.emit_numpy_struct_dtype(struct)
        table.insert(frags, dtype)
    end
    fileio.write(bundle_filename, table.concat(frags, "\n"))
end

local tests = {}
m._tests = tests

function tests.dtypes()
    local src = ([[
    struct Segment {
        p0: vec2f,
        p1: vec2f,
        zs: vec2f,
        arc_angle: f32,
        tool_rad: f32,
        tool_kind: i32,
        extra: i32,
    }
    ]]):dedent()

    local expected = ([[
    SEGMENT_DTYPE = np.dtype({
        "names": ["p0", "p1", "zs", "arc_angle", "tool_rad", "tool_kind", "extra"],
        "formats": [np.dtype((np.float32, 2)), np.dtype((np.float32, 2)), np.dtype((np.float32, 2)), np.float32, np.float32, np.int32, np.int32],
        "offsets": [0, 8, 16, 24, 28, 32, 36],
        "itemsize": 40
    })]]):dedent()

    local naga = require "analysis.naga"
    local parsed = naga.parse(src)
    local streq = require("utils.deepeq").string_equal

    local seg_dtype = m.emit_numpy_struct_dtype(parsed.types.Segment)
    print(seg_dtype)
    assert(streq(seg_dtype:strip(), expected:strip()))
end

return m