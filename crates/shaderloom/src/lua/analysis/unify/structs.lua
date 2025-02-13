-- analysis.unify
--
-- find merged structs, bindgroups, etc. in a collection
-- of shaders

local naga = require "analysis.naga"
local utils = require "utils.common"
local struct_unify = {}

---@class UniqueStructMapping
---@field structs StructDef[]
---@field mapping table<StructDef, StructDef>

---Unwrap an array or atomic into its inner type
---@param ty TypeDef
---@return TypeDef
local function unwrap(ty)
    if ty.kind == "atomic" or ty.kind == "array" then
        ---@cast ty AtomicDef|ArrayDef
        return ty.inner
    else
        return ty
    end
end

---Helper function to recursively find structs that have been shared
---@param target StructDef[]
---@param seen table<string, boolean>
---@param ty TypeDef
local function _find_shared_structs(target, seen, ty)
    local inner = unwrap(ty)
    if seen[inner.name] then return end
    if inner.kind ~= "struct" then return end
    ---@cast inner StructDef
    seen[inner.name] = true
    -- note that we process fields *before* inserting outself!
    -- this is implicitly topologically-sorting the struct defs
    -- by their dependencies on other struct defs.
    for _, field in ipairs(inner.members) do
        _find_shared_structs(target, seen, field.ty)
    end
    table.insert(target, inner)
end

---Find all structs shared with host in this shader
---@param shader ShaderDef
---@param target StructDef[]?
---@return StructDef[]
function struct_unify.find_shared_structs(shader, target)
    local structs, seen = target or {}, {}
    for _, var in pairs(shader.vars) do
        _find_shared_structs(structs, seen, var.ty)
    end
    return structs
end

local NON_CONCRETE_TYPES = utils.set{"texture", "sampler"}
local NESTED_TYPES = utils.set{"struct", "array"}

local _layout_sig, _field_sig

function _layout_sig(target, ty)
    local kind = ty.kind
    if NON_CONCRETE_TYPES[kind] then return false end
    if not NESTED_TYPES[kind] then
        table.insert(target, ty.name)
        return true
    end
    if kind == 'atomic' then
        return _layout_sig(target, ty.inner)
    elseif kind == 'array' then
        utils.insert(target, "{", ty.count or -1, ",")
        if not _layout_sig(target, ty.inner) then
            return false
        end
        utils.insert(target, "}")
        return true
    elseif kind == 'struct' then
        utils.insert(target, "{")
        for _, field in ipairs(ty.members) do
            if not _field_sig(target, field) then return false end
        end
        utils.insert(target, "}")
        return true
    else
        error("No layout for? " .. kind)
    end
    return false
end

function _field_sig(target, field)
    local name, offset, ty = field.name, field.offset, field.ty
    if not offset then return false end
    utils.insert(target, "{", name, ",", offset, ",", ty.name)
    if NESTED_TYPES[ty.kind] then
        utils.insert(target, ",")
        if not _layout_sig(target, ty) then return false end
    end
    utils.insert(target, "}")
    return true
end

---Produce a comparable signature of a type's memory layout if it exists
---@param ty TypeDef
---@return string | nil
function struct_unify.layout_signature(ty, known)
    if known and known[ty] then return known[ty] end
    local frags = {}
    if _layout_sig(frags, ty) then
        local sig = table.concat(frags)
        if known then known[ty] = sig end
        return sig
    else
        return nil
    end
end

---Shallow copy a struct type def, including making copies of members
---@param ty StructDef
---@return StructDef
local function _shallow_copy_struct_type(ty)
    local ret = utils.shallow_copy(ty)
    ---@cast ret StructDef
    ret.members = utils.map(ret.members, utils.shallow_copy)
    return ret
end

---Gather structs together by their memory layout signatures
---@param structs table<any, StructDef>
---@return table<StructDef, StructDef>
---@return table<string, StructDef>
function struct_unify.gather(structs)
    local exemplars = {}
    local remapping = {}
    local known = {}
    for _, struct in pairs(structs) do
        local sig = struct_unify.layout_signature(struct, known)
        if sig then
            if not exemplars[sig] then 
                exemplars[sig] = _shallow_copy_struct_type(struct)
            end
            remapping[struct] = exemplars[sig]
        end
    end
    return remapping, exemplars
end

---Assign names to get rid of name collisions
---Struct names are modified *in place*
---@param exemplars table<string, StructDef>
function struct_unify.assign_names(exemplars)
    local sorted_exemplars = utils.kv_pairs(exemplars)
    utils.sort_by_key(sorted_exemplars, function(item) return item[1] end)
    local name_counts = utils.default_table(0)
    for _, exemplar in ipairs(sorted_exemplars) do
        local name = exemplar[2].name
        name_counts[name] = name_counts[name] + 1
    end
    local names = {}
    for sig, exemplar in pairs(exemplars) do
        local name = exemplar.name
        if name_counts[name] > 1 then
            exemplar.name = name .. "_" .. sig:hash()
        end
    end
end

local _remap_array, _remap_struct, _remap_ty

function _remap_ty(target, seen, mapping, ty)
    if ty.kind == 'array' then
        return _remap_array(target, seen, mapping, ty)
    elseif ty.kind == 'struct' then
        return _remap_struct(target, seen, mapping, ty)
    else
        return ty
    end
end

--Semi deep copy a possibly nested array with a mapping
function _remap_array(target, seen, mapping, arr)
    local inner = arr.inner
    local new_inner = _remap_ty(target, seen, mapping, inner)
    if new_inner == inner then 
        return arr
    else
        return utils.merge({}, arr, {
            inner=new_inner,
            name=naga.array_name(new_inner, arr.count)
        })
    end
end

---Helper function to remap, topo sort, and fix members
function _remap_struct(target, seen, mapping, struct)
    struct = assert(mapping[struct], "Missing struct? " .. struct.name)
    if not seen[struct] then
        seen[struct] = true   
        for _, member in ipairs(struct.members) do
            member.ty = _remap_ty(target, seen, mapping, member.ty)
        end
        table.insert(target, struct)
    end
    return struct
end

---Find and unify structs shared with the host system
---@param shaders ShaderDef[]
---@return UniqueStructMapping
function struct_unify.unify_host_shared_structs(shaders)
    local structs = {}
    for _, shader in ipairs(shaders) do
        struct_unify.find_shared_structs(shader, structs)
    end
    local mapping, exemplars = struct_unify.gather(structs)
    struct_unify.assign_names(exemplars)

    local out_list = {}
    local seen = {}

    for _, struct in ipairs(structs) do
        _remap_struct(out_list, seen, mapping, struct)
    end

    return {
        structs = out_list,
        mapping = mapping
    }
end

local tests = {}
struct_unify._tests = tests

function tests.renaming()
    local src1 = [[
    struct PbrStruct {
        diffuse: vec4<f32>,
        metallic: vec4<f32>,
    }

    struct VertexStruct {
        position: vec4f,
        material: PbrStruct
    }
    
    @group(0) @binding(0) var<uniform> uniforms: VertexStruct;
    ]]
    local src2 = [[
    struct PbrStruct {
        diffuse:   vec4f,
        metallic:  vec4f,
    }

    struct VertexStruct {
        position: vec4f,
        normal: vec3f,
        material: PbrStruct
    }

    @group(0) @binding(0) var<uniform> uniforms: VertexStruct;
    ]]
    local deepprint = require "utils.deepprint"
    local structs = {}
    local p1 = naga.parse(src1)
    local p2 = naga.parse(src2)
    struct_unify.find_shared_structs(p1, structs)
    struct_unify.find_shared_structs(p2, structs)
    assert(#structs == 4, "Wrong number of structs?")
    assert(
        p1.types.VertexStruct ~= p2.types.VertexStruct, 
        "Parsed structs should be distinct!"
    )

    local mapping, exemplars = struct_unify.gather(structs)
    struct_unify.assign_names(exemplars)
    local exemplar_names = utils.dict_extract(exemplars, function(_, v)
        return v.name
    end)

    --local leq = require("utils.deepeq").list_equal
    deepprint(exemplar_names)
    assert(#exemplar_names == 3, "Wrong number of unique structs?")

    assert(
        mapping[p1.types.VertexStruct] ~= mapping[p2.types.VertexStruct],
        "VertexStructs should be unique!"
    )
    assert(
        mapping[p1.types.PbrStruct] == mapping[p2.types.PbrStruct],
        "PbrStructs should be merged!"
    )
end

function tests.unification()
    local src1 = [[
    struct Foozle {
        thinger: u32
    }

    struct PbrStruct {
        diffuse: vec4<f32>,
        metallic: vec4<f32>,
    }

    struct VertexStruct {
        position: vec4f,
        foozle: array<Foozle,3>,
        material: PbrStruct
    }
    
    @group(0) @binding(0) var<uniform> uniforms: VertexStruct;
    ]]
    local src2 = [[
    struct Foozle {
        thinger: i32
    }

    struct PbrStruct {
        diffuse:   vec4f,
        metallic:  vec4f,
    }

    struct VertexStruct {
        position: vec4f,
        foozle: array<Foozle,3>,
        material: PbrStruct
    }

    @group(0) @binding(0) var<uniform> uniforms: VertexStruct;
    ]]
    local deepprint = require "utils.deepprint"
    local naga = require "analysis.naga"
    local structs = {}
    local p1 = naga.parse(src1)
    local p2 = naga.parse(src2)

    local unified = struct_unify.unify_host_shared_structs({p1, p2})

    assert(#unified.structs == 5, "Wrong number of structs?")
    local struct_names = utils.map(unified.structs, function(v)
        return v.name
    end)

    local mapping = unified.mapping
    deepprint(struct_names)

    assert(
        mapping[p1.types.VertexStruct] ~= mapping[p2.types.VertexStruct],
        "VertexStructs should be unique!"
    )
    assert(
        mapping[p1.types.Foozle] ~= mapping[p2.types.Foozle],
        "Foozles should be unique!"
    )
    assert(
        mapping[p1.types.PbrStruct] == mapping[p2.types.PbrStruct],
        "PbrStructs should be merged!"
    )
end

function tests.layout_signatures()
    local src = [[
    struct VertexInput {
        @location(0) position: vec4f,
    }

    struct VertexStruct {
        position: vec4f,
    }

    struct PrimeIndices {
        erm: array<VertexStruct, 20>,
        data: array<u32>
    } // this is used as both input and output for convenience
    ]]
    local parsed = naga.parse_structs(src)
    local streq = require("utils.deepeq").string_equal
    --assert(unify.layout_signature(parsed.VertexInput) == nil)
    print(struct_unify.layout_signature(parsed.PrimeIndices))
    assert(streq(
        struct_unify.layout_signature(parsed.VertexStruct), 
        '{{position,0,vec4<f32>}}'
    ))
end

return struct_unify