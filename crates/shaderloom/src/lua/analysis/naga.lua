local deep_print = require "utils.deepprint"

local naga = {}

local type_mt = {}
local function Type(t)
    return setmetatable(t, type_mt)
end

local function fixnull(val)
    if val == null then return nil end
    return val
end

local SCALARS = {
    Uint = "u",
    Sint = "i",
    Float = "f",
    bool = Type{kind="scalar", name="bool", size=4}, -- size of bool: ?
    f32 = Type{kind="scalar", name="f32", size=4},
    f16 = Type{kind="scalar", name="f16", size=2},
    u32 = Type{kind="scalar", name="u32", size=4},
    i32 = Type{kind="scalar", name="i32", size=4},
}

local function fix_scalar(registry, s)
    if s.inner then s = s.inner.Scalar end
    if s.kind == "Bool" then return SCALARS.bool end
    local prefix = assert(SCALARS[s.kind])
    local bitwidth = s.width * 8
    local name = ("%s%d"):format(prefix, bitwidth)
    return assert(SCALARS[name])
end

local VECSIZES = {
    Bi = 2,
    Tri = 3,
    Quad = 4,
}

local function fix_vector(registry, s)
    if s.inner then s = s.inner.Vector end
    local inner = fix_scalar(registry, s.scalar)
    local count = VECSIZES[s.size]
    local size = count * inner.size
    local name = ("vec%d<%s>"):format(count, inner.name)
    return Type{kind="vector", name=name, inner=inner, size=size, count=count}
end

local function fix_matrix(registry, s)
    if s.inner then s = s.inner.Matrix end
    local rows = VECSIZES[s.rows]
    local cols = VECSIZES[s.columns]
    local inner = fix_scalar(registry, s.scalar)
    local name = ("mat%dx%d<%s>"):format(cols, rows, inner.name)
    local size = rows * cols * inner.size -- TODO: fix for vec3's!
    return Type{kind="matrix", name=name, inner=inner, size=size, rows=rows, cols=cols}
end

local function fix_struct(registry, s)
    local name = s.name
    s = s.inner.Struct
    local members = {}
    for i, v in ipairs(s.members) do
        members[i] = {
            binding = fixnull(v.binding),
            name = v.name,
            offset = v.offset,
            ty = registry[v.ty]
        }
    end
    return Type{kind="struct", name=name, size=s.span, members=members}
end

local function fix_array_count(count)
    if count == "Dynamic" then return nil end
    if count.Constant then return count.Constant end
    error("Couldn't interpret array size:", count)
end

local function fix_array(registry, s)
    if s.inner then s = s.inner.Array end
    local inner = registry[s.base]
    local count = fix_array_count(s.size)
    local stride = s.stride
    local size = nil
    if count and stride then
        size = count * stride
    end
    local name
    if count then
        name = ("array<%s,%d>"):format(inner.name, count)
    else
        name = ("array<%s>"):format(inner.name)
    end
    return Type{kind="array", name=name, size=size, count=count, inner=inner, stride=stride}
end

local TEXTUREDIMS = {
    D1 = "1d",
    D2 = "2d",
    D3 = "3d",
    Cube = "cube"
}

local TEXCLASSES = {
    Storage = "texture_storage",
    Depth = "texture_depth",
    Sampled = "texture"
}

local TEXSAMPLEFORMATS = {
    Float = "f32",
    Sint = "i32",
    Uint = "u32",
}

local function image_name(s, classname, class)
    local texname = assert(TEXCLASSES[classname])
    if class.multi then
        texname = texname .. "_multisampled"
    end
    texname = texname .. "_" .. TEXTUREDIMS[s.dim]
    if s.arrayed then
        texname = texname .. "_array"
    end
    if class.kind then
        texname = texname .. "<" .. TEXSAMPLEFORMATS[class.kind] .. ">"
    elseif class.format then
        texname = texname .. ("<%s,%s>"):format(class.format, class.access)
    end
    return texname
end

local function fix_image(registry, s)
    if s.inner then s = s.inner.Image end
    local classname = next(s.class)
    local class = s.class[classname]
    local name = image_name(s, classname, class)
    local dim = TEXTUREDIMS[s.dim]
    local format = nil
    if class.kind then
        format = TEXCLASSES[class.kind]
    elseif class.format then
        format = class.format:lower()
    end
    return Type{
        kind="texture",
        name=name,
        class=classname:lower(),
        array=s.arrayed,
        dimension=dim,
        format=format,
        access=class.access,
        multisampled=class.multi
    }
end

local function fix_sampler(registry, s)
    if s.inner then s = s.inner.Sampler end
    local name = s.comparison and "sampler_comparison" or "sampler"
    return Type{
        kind="sampler",
        name=name,
        comparison=s.comparison
    }
end

local function fix_atomic(registry, s)
    if s.inner then s = s.inner.Atomic end
    local inner = fix_scalar(registry, s)
    return Type{
        kind="atomic",
        name=("atomic<%s>"):format(inner.name),
        inner=inner,
    }
end

local VARTYPES = {
    Scalar = fix_scalar,
    Vector = fix_vector,
    Matrix = fix_matrix,
    Struct = fix_struct,
    Array = fix_array,
    Image = fix_image,
    Sampler = fix_sampler,
    Atomic = fix_atomic,
}

local function fix_and_register_type(registry, idx, t)
    local enum_kind = next(t.inner)
    local fixer = VARTYPES[enum_kind]
    if not fixer then
        deep_print(t)
        error("Couldn't infer type of type " .. enum_kind)
    end

    local fixed = assert(fixer(registry, t))
    registry[idx] = fixed
    registry[fixed.name] = fixed
    return fixed
end
--     global_variables = {
--          1 = {
--              space = {
--                  Storage = {
--                      access = [string] "LOAD | STORE",
--                  },
--              },
--              ty = [number] 10,
--              name = [string] "v_indices",
--              init = [null],
--              binding = {
--                  binding = [number] 0,
--                  group = [number] 0,
--              },
--          },
--          2 = {
--              space = [string] "Handle",
--              ty = [number] 11,
--              name = [string] "tex_whatever",
--              init = [null],
--              binding = {
--                  binding = [number] 1,
--                  group = [number] 0,
--              },
--          },
--          3 = {
--              space = [string] "Handle",
--              ty = [number] 12,
--              name = [string] "samp_a",
--              init = [null],
--              binding = {
--                  binding = [number] 2,
--                  group = [number] 0,
--              },
--          },
--          4 = {
--              space = [string] "Handle",
--              ty = [number] 13,
--              name = [string] "samp_b",
--              init = [null],
--              binding = {
--                  binding = [number] 3,
--                  group = [number] 0,
--              },
--          },
--          5 = {
--              space = {
--                  Storage = {
--                      access = [string] "LOAD | STORE",
--                  },
--              },
--              ty = [number] 15,
--              name = [string] "atomic_array",
--              init = [null],
--              binding = {
--                  binding = [number] 4,
--                  group = [number] 0,
--              },
--          },



local function fix_and_register_var(registry, vars, item)
    local space, access = nil, nil
    if type(item.space) == "string" then
        space = item.space:lower()
    else
        space = next(item.space)
        access = item.space[space].access
    end
    local ty = assert(registry[item.ty])
    local binding = fixnull(item.binding)
    vars[item.name] = {
        name = item.name,
        ty = ty,
        space = space,
        access = access,
        binding = binding,
    }
end

local function fixup(data)
    data = data.module
    -- fix types first off
    local registry = {}
    for idx, t in ipairs(data.types) do
        fix_and_register_type(registry, idx-1, t)
    end
    local vars = {}
    for _, var in ipairs(data.global_variables) do
        fix_and_register_var(registry, vars, var)
    end
    deep_print(data)
    return {
        raw=data,
        types=registry,
        vars=vars,
    }
end

function naga.parse(source)
    return fixup(loom:parse_wgsl(source))
end

local tests = {}
naga._tests = tests

function tests:parse_primitives()
    local src = [[
    var<workgroup> v_u32: u32 = 0;
    var<workgroup> v_i32: i32 = 0;
    var<workgroup> v_f32: f32 = 0.0;
    var<workgroup> v_bool: bool = false;

    @compute @workgroup_size(1) fn main() {}
    ]]

    local parsed = naga.parse(src)
    local types, vars = parsed.types, parsed.vars
    assert(types.u32 == SCALARS.u32, "u32 parsed as scalar")
    assert(types.i32 == SCALARS.i32, "i32 parsed as scalar")
    assert(types.f32 == SCALARS.f32, "f32 parsed as scalar")
    assert(types.bool == SCALARS.bool, "bool parsed as scalar")

    assert(vars.v_u32.ty == SCALARS.u32, "parsed var v_u32")
    assert(vars.v_i32.ty == SCALARS.i32, "parsed var v_i32")
    assert(vars.v_f32.ty == SCALARS.f32, "parsed var v_f32")
    assert(vars.v_bool.ty == SCALARS.bool, "parsed var v_bool")
end

return naga
