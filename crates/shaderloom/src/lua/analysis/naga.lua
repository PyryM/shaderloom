local deep_print = require "utils.deepprint"

local naga = {}

local type_mt = {}
local function Type(t)
    return setmetatable(t, type_mt)
end

-- types = {
--     1 = {
--         name = [null],
--         inner = {
--             Scalar = {
--                 width = [number] 4,
--                 kind = [string] "Float",
--             },
--         },
--     },
--     2 = {
--         name = [null],
--         inner = {
--             Vector = {
--                 scalar = {
--                     width = [number] 4,
--                     kind = [string] "Float",
--                 },
--                 size = [string] "Quad",
--             },
--         },
--     },
--     3 = {
--         name = [string] "Hmm",
--         inner = {
--             Struct = {
--                 span = [number] 32,
--                 members = {
--                     1 = {
--                         binding = [null],
--                         ty = [number] 1,
--                         name = [string] "x",
--                         offset = [number] 0,
--                     },
--                     2 = {
--                         binding = [null],
--                         ty = [number] 0,
--                         name = [string] "y",
--                         offset = [number] 16,
--                     },
--                 },
--             },
--         },
--     },
--     4 = {
--         name = [null],
--         inner = {
--             Array = {
--                 size = {
--                     Constant = [number] 100,
--                 },
--                 base = [number] 2,
--                 stride = [number] 32,
--             },
--         },
--     },
--     5 = {
--         name = [null],
--         inner = {
--             Scalar = {
--                 width = [number] 4,
--                 kind = [string] "Uint",
--             },
--         },
--     },
--     6 = {
--         name = [null],
--         inner = {
--             Array = {
--                 size = [string] "Dynamic",
--                 base = [number] 4,
--                 stride = [number] 4,
--             },
--         },
--     },
--     7 = {
--         name = [string] "PrimeIndices",
--         inner = {
--             Struct = {
--                 span = [number] 3216,
--                 members = {
--                     1 = {
--                         binding = [null],
--                         ty = [number] 3,
--                         name = [string] "erm",
--                         offset = [number] 0,
--                     },
--                     2 = {
--                         binding = [null],
--                         ty = [number] 5,
--                         name = [string] "data",
--                         offset = [number] 3200,
--                     },
--                 },
--             },
--         },
--     },
--     8 = {
--         name = [null],
--         inner = {
--             Vector = {
--                 scalar = {
--                     width = [number] 4,
--                     kind = [string] "Uint",
--                 },
--                 size = [string] "Tri",
--             },
--         },
--     },
-- },

local function fixnull(val)
    if val == null then return nil end
    return val
end

--         name = [null],
--         inner = {
--             Scalar = {
--                 width = [number] 4,
--                 kind = [string] "Uint",
--             },
--         },
local SCALARS = {
    Uint = "u",
    Sint = "i",
    Float = "f",
    f32 = Type{kind="scalar", name="f32", size=4},
    f16 = Type{kind="scalar", name="f16", size=2},
    u32 = Type{kind="scalar", name="u32", size=4},
    i32 = Type{kind="scalar", name="i32", size=4},
}
local function fix_scalar(registry, s)
    if s.inner then s = s.inner.Scalar end
    local prefix = assert(SCALARS[s.kind])
    local bitwidth = s.width * 8
    local name = ("%s%d"):format(prefix, bitwidth)
    return assert(SCALARS[name])
end

-- inner = {
--     Vector = {
--         size = [string] "Quad",
--         scalar = {
--             kind = [string] "Float",
--             width = [number] 4,
--         },
--     },
-- },
-- name = [null],
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

-- inner = {
--     Matrix = {
--         rows = [string] "Quad",
--         scalar = {
--             kind = [string] "Float",
--             width = [number] 4,
--         },
--         columns = [string] "Quad",
--     },
-- },
-- name = [null],
local function fix_matrix(registry, s)
    if s.inner then s = s.inner.Matrix end
    local rows = VECSIZES[s.rows]
    local cols = VECSIZES[s.columns]
    local inner = fix_scalar(registry, s.scalar)
    local name = ("mat%dx%d<%s>"):format(cols, rows, inner.name)
    local size = rows * cols * inner.size -- TODO: fix for vec3's!
    return Type{kind="matrix", name=name, inner=inner, size=size, rows=rows, cols=cols}
end

-- inner = {
--     Struct = {
--         span = [number] 12816,
--         members = {
--             1 = {
--                 binding = [null],
--                 name = [string] "erm",
--                 offset = [number] 0,
--                 ty = [number] 8,
--             },
--             2 = {
--                 binding = [null],
--                 name = [string] "data",
--                 offset = [number] 12800,
--                 ty = [number] 9,
--             },
--         },
--     },
-- },
-- name = [string] "PrimeIndices",
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

-- inner = {
--     Array = {
--         stride = [number] 128,
--         base = [number] 7,
--         size = {
--             Constant = [number] 100,
--         },
--     },
-- },
-- name = [null],
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

-- inner = {
--     Image = {
--         arrayed = [boolean] false,
--         class = {
--             Sampled = {
--                 multi = [boolean] false,
--                 kind = [string] "Float",
--             },
--         },
--         dim = [string] "Cube",
--     },
-- },
-- VAL = {
--     name = [null],
--     inner = {
--         Image = {
--             dim = [string] "D2",
--             arrayed = [boolean] false,
--             class = {
--                 Sampled = {
--                     kind = [string] "Float",
--                     multi = [boolean] false,
--                 },
--             },
--         },
--     },
-- },
-- VAL = {
--     dim = [string] "D2",
--     class = {
--         Storage = {
--             access = [string] "STORE",
--             format = [string] "Rgba8Unorm",
--         },
--     },
--     arrayed = [boolean] false,
-- },
-- class = {
--     Depth = {
--         multi = [boolean] false,
--     },
-- },
-- dim = [string] "D2",
-- arrayed = [boolean] false,
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

local function fixup(data)
    data = data.module
    -- fix types first off
    local registry = {}
    local types = data.types
    local tcount = #types
    for idx = 1, tcount do
        fix_and_register_type(registry, idx-1, types[idx])
    end
    return {
        raw=data,
        types=registry
    }
end

function naga.parse(source)
    return fixup(loom:parse_wgsl(source))
end

return naga