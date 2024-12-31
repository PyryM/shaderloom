-- type definitions for the Lua language server plugin

---@meta

---@class loom
loom = {}

---@param pattern string
function loom:glob(pattern) end

---@param source string
function loom:parse_wgsl(source) end

---@param msg string
function loom:print(msg) end

---@class null
null = {}

---@type { [string]: function }
_EMBED = {}
