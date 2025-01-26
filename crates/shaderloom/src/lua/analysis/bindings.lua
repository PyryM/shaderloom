-- analysis.bindings
-- 
-- analyze bind groups

local class = require "miniclass"
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
                view_dimension = ty.dimension
            }
        else
            return {
                kind = "texture",
                format = ty.format,
                view_dimension = ty.dimension,
                multisampled = ty.multisampled
            }
        end
    end,
    sampler = function(def)
        local ty = def.ty
        ---@cast ty SamplerDef
        return {
            kind="sampler",
            sampler_kind=(ty.comparison and "comparison") or "filtering"
        }
    end,
    acceleration_structure = function(def)
        return {kind="acceleration_structure"}
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
    local def = BIND_DEFS[var.ty.kind] or BIND_DEFS.buffer
    return {
        var=var,
        binding=var.binding.binding,
        visibility=var.visibility or {vertex=true, fragment=true, compute=true},
        ty=def(var),
        count=binding_count(var.ty)
    }
end

---Produce a comparable string signature for a binding
---@param binding VarDef
---@return string|nil
function bindings.binding_signature(binding)

end

local tests = {}
bindings._tests = tests

return bindings