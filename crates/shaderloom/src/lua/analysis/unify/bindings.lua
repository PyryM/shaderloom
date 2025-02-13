-- analysis.bindings
-- 
-- analyze bind groups

local class = require "miniclass"
local utils = require "utils.common"
local bindings = {}

-- pub struct BindGroupLayoutEntry {
--     pub binding: u32,
--     pub visibility: ShaderStages,
--     pub ty: BindingType,
--     pub count: Option<NonZero<u32>>,
-- }
-- pub enum BindingType {
--     Buffer {
--         ty: BufferBindingType,
--         has_dynamic_offset: bool,
--         min_binding_size: Option<NonZero<u64>>,
--     },
--     Sampler(SamplerBindingType),
--     Texture {
--         sample_type: TextureSampleType,
--         view_dimension: TextureViewDimension,
--         multisampled: bool,
--     },
--     StorageTexture {
--         access: StorageTextureAccess,
--         format: TextureFormat,
--         view_dimension: TextureViewDimension,
--     },
--     AccelerationStructure,
-- }
-- pub enum BufferBindingType {
--     Uniform,
--     Storage {
--         read_only: bool,
--     },
-- }

-- D1 = 0,
-- D2 = 1,
-- D2Array = 2,
-- Cube = 3,
-- CubeArray = 4,
-- D3 = 5,

---@class BindingType
---@field kind "buffer" | "sampler" | "texture" | "storage_texture" | "acceleration_structure"
---@field signature string

---@class BufferBinding: BindingType
---@field space "uniform" | "storage"
---@field dynamic_offset boolean
---@field read_only boolean?
---@field min_binding_size number?

---@class SamplerBinding: BindingType
---@field sampler_kind "filtering" | "non_filtering" | "comparison"

---@class TextureBinding: BindingType
---@field format "float" | "unfilterable_float" | "depth" | "sint" | "uint"
---@field view_dimension string
---@field multisampled boolean

---@class StorageTextureBinding: BindingType
---@field access string
---@field format string
---@field view_dimension string

---@class AccelerationStructureBinding: BindingType

---@class BindGroupLayoutEntry
---@field var VarDef
---@field binding number
---@field visibility Visibility
---@field ty BindingType
---@field count number?
---@field signature string

---@class BindGroupLayout
---@field bindings BindGroupLayoutEntry[]
---@field name string

---@class UnifiedBindGroupLayouts
---@field layouts BindGroupLayout[]
---@field mapping table<table, BindGroupLayout>

local function buffer_sig(space, readonly)
    if space == "uniform" then
        return "buffer<uniform>"
    else
        return ("buffer<%s,%s>"):format(space, (readonly and "read") or "readwrite")
    end
end

---@type table<string, fun(def: VarDef): BindingType>
local BIND_DEFS = {
    texture = function(def)
        local ty = def.ty
        ---@cast ty TextureDef
        if ty.class == "storage" then
            return {
                kind = "storage_texture",
                access = ty.access,
                format = ty.format,
                view_dimension = ty.dimension,
                signature = ty.name,
            }
        else
            return {
                kind = "texture",
                format = ty.format,
                view_dimension = ty.dimension,
                multisampled = ty.multisampled,
                signature = ty.name,
            }
        end
    end,
    sampler = function(def)
        local ty = def.ty
        ---@cast ty SamplerDef
        return {
            kind="sampler",
            sampler_kind=(ty.comparison and "comparison") or "filtering",
            signature = ty.name,
        }
    end,
    acceleration_structure = function(def)
        return {kind="acceleration_structure", signature="acceleration_structure"}
    end,
    binding_array = function(def)
        error("Binding arrays NYI!")
    end,
    buffer = function(def)
        return {
            kind="buffer",
            space=def.space,
            dynamic_offset=false, -- ???
            read_only=(def.access=="read"),
            signature=buffer_sig(def.space,def.access=="read")
        }
    end
}

---Returns the number of bindings for binding_array types
---@param ty TypeDef
---@return number?
local function binding_count(ty)
    if ty.kind ~= "binding_array" then return nil end
    ---@cast ty BindingArrayDef
    return ty.count
end

---Infer the BindGroupLayoutEntry of a VarDef
---@param var VarDef
---@return BindGroupLayoutEntry?
function bindings.infer_layout_entry(var)
    if not var.binding then return nil end
    ---@type fun(def: VarDef): BindingType
    local def = assert(BIND_DEFS[var.ty.kind] or BIND_DEFS.buffer, "Missing def!")
    local ty = def(var)
    return {
        var=var,
        binding=var.binding.binding,
        visibility=var.visibility or {vertex=true, fragment=true, compute=true},
        ty=ty,
        signature=ty.signature,
        count=binding_count(var.ty)
    }
end

---Infer the layout of a bind group
---@param bindgroup BindGroupInfo
---@param name string
---@return BindGroupLayout
function bindings.infer_bind_group_layout(bindgroup, name)
    ---@type BindGroupLayoutEntry[]
    local group_bindings = {}
    for _idx, bind_info in pairs(bindgroup.bindings) do
        table.insert(assert(bindings.infer_layout_entry(bind_info)))
    end
    utils.sort_by_key(group_bindings, function(group) return group.binding end)
    return {
        name = name,
        bindings = group_bindings
    }
end

---Merge a bindgroup into a target eh
---@param target BindGroupLayout
---@param incoming BindGroupLayout
function bindings.merge_layout(target, incoming)
    print("Warning: just assuming target and incoming are the same!")
end

---Find bind groups across shaders
---@param shaders ShaderDef[]
---@return UnifiedBindGroupLayouts
function bindings.unify_bind_groups(shaders)
    local layouts = {}
    local shared_layouts = {}
    local mapping = {}
    for shader_idx, shader in ipairs(shaders) do
        local shader_name = shader.name or ("__shader_" .. shader_idx)
        for group_idx, group in pairs(shader.bindgroups) do
            if group.shared then
                local groupname = assert(group.name, "Shared bindgroup must have explicit name!")
                local layout = bindings.infer_bind_group_layout(group, groupname)
                if shared_layouts[groupname] then
                    bindings.merge_layout(shared_layouts[groupname], layout)
                    mapping[group] = shared_layouts[groupname]
                else
                    shared_layouts[groupname] = layout
                    table.insert(layouts, layout)
                    mapping[group] = layout
                end
            else
                -- simpler? case: just give the group a name that shouldn't collide
                -- with anything and insert it
                local groupname = ("%s_%s"):format(shader_name, group.name or ("_group_" .. group_idx))
                local layout = bindings.infer_bind_group_layout(group, groupname)
                table.insert(layouts, layout)
                mapping[group] = layout
            end
        end
    end
    return {layouts=layouts, mapping=mapping}
end

local tests = {}
bindings._tests = tests

return bindings