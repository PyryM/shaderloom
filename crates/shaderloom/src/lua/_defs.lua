-- type definitions for the Lua language server plugin

---@meta

---@class loom
loom = {}


---@class GlobItem
---@field path string
---@field abspath string?
---@field is_file boolean
---@field is_dir boolean
---@field file_name string?

---@param pattern string
---@return GlobItem[]
function loom:glob(pattern) end

---@param source string
function loom:parse_wgsl(source) end

---@param source string
---@param flags number?
---@return any|nil
---@return string|nil
function loom:parse_and_validate_wgsl(source, flags) end

---@param msg string
function loom:print(msg) end

---@class null
null = {}

---@type { [string]: function }
_EMBED = {}

---@type any[]
_SOURCE_LOCATIONS = {}