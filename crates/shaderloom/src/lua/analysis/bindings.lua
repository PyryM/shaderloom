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
---@field kind "uniform" | "storage"
---@field dynamic_offset boolean
---@field read_only boolean?
---@field min_binding_size number?

---@class SamplerBinding: BindingType
---@field kind "filtering" | "non_filtering" | "comparison"

---@class TextureBinding: BindingType
---@field sample_type "float" | "unfilterable_float" | "depth" | "sint" | "uint"
---@field view_dimension string
---@field multisampled boolean

---@class StorageTextureBinding: BindingType
---@field access string
---@field format string
---@field view_dimension string

---@class AccelerationStructureBinding: BindingType

---@class BindGroupLayoutEntry
---@field visibility table<string, boolean>
---@field ty BindingType
---@field count number?

---Infer the BindGroupLayoutEntry of a VarDef
---@param var VarDef
---@return BindGroupLayoutEntry?
function bindings.infer_layout_entry(var)
    return nil
end

---Produce a comparable string signature for a binding
---@param binding VarDef
---@return string|nil
function bindings.binding_signature(binding)

end

local tests = {}
bindings._tests = tests

return bindings