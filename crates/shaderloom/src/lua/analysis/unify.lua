-- analysis.unify
--
-- find merged structs, bindgroups, etc. in a collection
-- of shaders

local utils = require "utils.common"
local unify = {}

---@class UnifiedStruct
---@field inner StructDef
---@field unique_name string
---@field source_name string

---@class UniqueStructMapping
---@field structs UnifiedStruct[]
---@field mapping table<StructDef, UnifiedStruct>

---Returns whether two StructDefs are exactly the same
---@param a StructDef
---@param b StructDef
---@return boolean
function unify.struct_equals(a, b)
    if #a.members ~= #b.members then return false end
    for idx = 1, #a.members do
        local left = a.members[idx]
        local right = b.members[idx]
        if left.offset ~= right.offset then return false end
        if left.ty.name ~= right.ty.name then return false end
        -- TODO: consider what happens when nested structs are unified
        -- (or NOT!)
    end
    return true
end

---Unwrap an array or atomic into its inner type
---@param ty TypeDef
---@return TypeDef
function unify.unwrap(ty)
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
    local inner = unify.unwrap(ty)
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
---@return StructDef[]
function unify.find_shared_structs(shader)
    local structs, seen = {}, {}
    for _, var in pairs(shader.vars) do
        _find_shared_structs(structs, seen, var.ty)
    end
    return structs
end

---Find and unify structs shared with the host system
---@param shaders ShaderDef[]
---@return UniqueStructMapping
function unify.unify_host_shared_structs(shaders)
    return {
        structs = {},
        mapping = {}
    }
end

function unify.unify_bind_groups(shaders)
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
function unify.layout_signature(ty)
    local frags = {}
    if _layout_sig(frags, ty) then
        return table.concat(frags)
    else
        return nil
    end
end

---Gather structs together by their memory layout signatures
---@param structs StructDef[]
---@return table<StructDef, StructDef>
---@return table<string, StructDef>
function unify.gather(structs)
    local exemplars = {}
    local remapping = {}
    for _, struct in pairs(structs) do
        local sig = unify.layout_signature(struct)
        if sig then
            if not exemplars[sig] then exemplars[sig] = struct end
            remapping[sig] = exemplars[sig]
        end
    end
    return remapping, exemplars
end

local tests = {}
unify._tests = tests

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
    local naga = require "analysis.naga"
    local parsed = naga.parse_structs(src)
    local streq = require("utils.deepeq").string_equal
    --assert(unify.layout_signature(parsed.VertexInput) == nil)
    print(unify.layout_signature(parsed.PrimeIndices))
    assert(streq(
        unify.layout_signature(parsed.VertexStruct), 
        '{{position,0,vec4<f32>}}'
    ))
    assert(false)
end

return unify