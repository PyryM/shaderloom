local deep_print = require "utils.deepprint"
local utils = require "utils.common"
local default_table = utils.default_table

local naga = {}

---@class TypeDef
---@field kind string
---@field name string

local type_mt = {}
local function Type(t)
    return setmetatable(t, type_mt)
end

local function fixnull(val, mapfunc)
    if val == null then return nil end
    if mapfunc then return mapfunc(val) else return val end
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

---@class StructMember
---@field name string
---@field offset number
---@field binding table?
---@field ty TypeDef

---@class StructDef: TypeDef
---@field size number
---@field members StructMember[]

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

---@class ArrayDef: TypeDef
---@field size number
---@field stride number
---@field count number?
---@field inner TypeDef

---Fix an array type definition
---@param registry table<string|number, TypeDef>
---@param s any
---@return ArrayDef
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

---@class AtomicDef: TypeDef
---@field inner TypeDef

---Fix an atomic type definition
---@param registry table<string|number, TypeDef>
---@param s any
---@return AtomicDef
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

---@class VarDef
---@field name string
---@field ty TypeDef
---@field space string
---@field access table?
---@field binding table?

local function fix_and_register_var(registry, vars, bindgroups, item)
    local space, access = nil, nil
    if type(item.space) == "string" then
        space = item.space:lower()
    else
        space = next(item.space)
        access = item.space[space].access
    end
    local ty = assert(registry[item.ty])
    local binding = fixnull(item.binding)
    local var = {
        name = item.name,
        ty = ty,
        space = space,
        access = access,
        binding = binding,
    }
    vars[item.name] = var
    if binding then
        bindgroups[binding.group].bindings[binding.binding] = var
    end
end

---@class FunctionArg
---@field name string
---@field ty TypeDef
---@field binding table?

local function fix_function_arg(registry, arg)
    return {
        name = arg.name,
        ty = assert(registry[arg.ty]),
        binding = fixnull(arg.binding),
    }
end

---@class FunctionDef
---@field arguments FunctionArg[]
---@field result FunctionArg?

local function fix_function(registry, func)
    return {
        arguments = utils.map(func.arguments, function(arg)
            return fix_function_arg(registry, arg)
        end),
        result = fixnull(func.result, function(res)
            return fix_function_arg(registry, res)
        end)
    }
end

---@class EntryPointDef
---@field name string
---@field stage string
---@field workgroup_size [number, number, number]
---@field func any

local function fix_entry_point(registry, target, entry)
    local stage = entry.stage:lower()
    table.insert(target[stage], {
        name = entry.name,
        stage = stage,
        workgroup_size = entry.workgroup_size,
        func = fix_function(registry, entry["function"])
    })
end

---@class ShaderDef
---@field raw any
---@field types table<number | string, TypeDef>
---@field vars table<string, VarDef>
---@field bindgroups table<number, table>
---@field entry_points table<string, EntryPointDef[]>

---Fix naga-returned parse result
---@param data any
---@param annotations any
---@return ShaderDef
local function fixup(data, annotations)
    annotations = annotations or {}
    local visibility_annotations = annotations.visibility or {}
    local bindgroup_annotations = annotations.bindgroups or {}

    data = data.module
    -- fix types first off
    local registry = {}
    for idx, t in ipairs(data.types) do
        fix_and_register_type(registry, idx-1, t)
    end
    local vars = {}
    local bindgroups = default_table(function() return {bindings={}} end)
    for _, var in ipairs(data.global_variables) do
        fix_and_register_var(registry, vars, bindgroups, var)
    end
    setmetatable(bindgroups, nil)
    local entry_points = default_table({})
    for _, entry in ipairs(data.entry_points) do
        fix_entry_point(registry, entry_points, entry)
    end
    setmetatable(entry_points, nil)
    return {
        raw=data,
        types=registry,
        vars=vars,
        bindgroups=bindgroups,
        entry_points=entry_points,
    }
end

---Parse WGSL source, optionally validating
---@param shader string | PreprocessorOutput
---@param validate boolean?
---@return ShaderDef
---@return string|nil
function naga.parse(shader, validate)
    local source, annotations
    if type(shader) == 'table' then
        source, annotations = shader.source, shader.annotations
    else
        source = shader
    end
    local parsed, validation_errors
    if validate then
        parsed, validation_errors = loom:parse_and_validate_wgsl(source)
    else
        parsed = loom:parse_wgsl(source)
    end
    return fixup(parsed, annotations), validation_errors
end

---Parse WGSL source, returning only the struct definitions
---@param shader string | PreprocessorOutput
---@return table<string, StructDef>
function naga.parse_structs(shader)
    local parsed = naga.parse(shader)
    return utils.filter_dict(parsed.types, function(name, ty)
        return type(name) == 'string' and ty.kind == 'struct'
    end)
end

local tests = {}
naga._tests = tests

function tests:validation()
    local src = [[
    var<private> pos: array<vec2f, 3> = array<vec2f, 3>(
        vec2f(-1.0, -1.0), 
        vec2f(-1.0, 3.0), 
        vec2f(3.0, -1.0)
    );

    @vertex
    fn vertexMain(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4f {
        return pos[vertexIndex];
    }

    @fragment
    fn fragmentMain(@builtin(position) fragpos: vec4f) -> @location(0) vec4f {
        return vec2f(0.0, 0.0);
    }
    ]]
    local parsed, errs = naga.parse(src, true)
    print(errs)
    assert(errs ~= nil)
end

function tests:parse_entrypoints()
    local deepeq = require("utils.deepeq")
    local streq = deepeq.string_equal
    local leq = deepeq.list_equal

    local src_render = [[
    struct FragtestUniforms {
        @align(16) color0: vec4f,
        @align(16) color1: vec4f,
        @align(16) center: vec2f,
        @align(16) scale: f32,
    }

    @group(0) @binding(0) var<uniform> uniforms: FragtestUniforms;

    var<private> pos: array<vec2f, 3> = array<vec2f, 3>(
        vec2f(-1.0, -1.0), 
        vec2f(-1.0, 3.0), 
        vec2f(3.0, -1.0)
    );

    @vertex
    fn vertexMain(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4f {
        return vec4f(pos[vertexIndex], 1.0, 1.0);
    }

    @fragment
    fn fragmentMain(@builtin(position) fragpos: vec4f) -> @location(0) vec4f {
        let rad = length(fragpos.xy - uniforms.center);
        let alpha = cos(rad * uniforms.scale) * 0.5 + 0.5;
        return mix(uniforms.color0, uniforms.color1, alpha);
    }
    ]]
    local entry_points = naga.parse(src_render).entry_points
    assert(streq(entry_points.vertex[1].name, "vertexMain"))
    assert(streq(entry_points.fragment[1].name, "fragmentMain"))

    local src_compute = [[
    @compute @workgroup_size(1, 16) fn compute_main() {}
    ]]
    local entry_points = naga.parse(src_compute).entry_points
    assert(streq(entry_points.compute[1].name, "compute_main"))
    assert(leq(entry_points.compute[1].workgroup_size, {1, 16, 1}))
end

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

function tests:parse_structs()
    local src = [[
    struct VertexInput {
        @location(0) position: vec4f,
    }

    struct PrimeIndices {
        erm: array<u32, 100>,
        data: array<u32>
    } // this is used as both input and output for convenience
    ]]
    local parsed = naga.parse_structs(src)
    assert(parsed.VertexInput, "VertexInput exists")
    assert(parsed.PrimeIndices, "PrimeIndices exists")
    assert(#utils.kv_pairs(parsed) == 2, "Only two things returned")
end

function tests:parse_bindgroups()
    local src = [[
    struct VertexInput {
        @location(0) position: vec4f,
    }

    struct PrimeIndices {
        erm: array<u32, 100>,
        data: array<u32>
    } // this is used as both input and output for convenience

    @group(0) @binding(0)
    var<storage,read_write> v_indices: PrimeIndices;

    @group(0) @binding(1)
    var tex_whatever: texture_multisampled_2d<f32>;

    @group(1) @binding(0)
    var samp_a: sampler;

    @group(1) @binding(1)
    var samp_b: sampler_comparison;

    @compute @workgroup_size(1) fn main() {}
    ]]

    local parsed = naga.parse(src)
    local types, vars, bindgroups = parsed.types, parsed.vars, parsed.bindgroups
    assert(bindgroups[0].bindings[0].name == "v_indices")
    assert(bindgroups[0].bindings[0].ty == types.PrimeIndices)
    assert(bindgroups[1].bindings[1].name == "samp_b")
    assert(bindgroups[1].bindings[1].ty == types.sampler_comparison)
end

return naga
