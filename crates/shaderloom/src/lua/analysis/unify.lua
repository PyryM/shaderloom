-- analysis.unify
--
-- find merged structs, bindgroups, etc. in a collection
-- of shaders

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

return unify