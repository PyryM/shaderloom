-- does a thing

local chunker = {}

-- A chunk may be:
-- {kind: "lua", source: string}
-- {kind: "raw", source: string}
-- {kind: "lua_expr", source: string}
-- {kind: "mixed", chunk: chunk[]}

---
--- Split source code into a list of chunks
---
---@param src string
---@return chunks table[]
function chunker.split_source(src)
    local chunks = {}



    return chunks
end

---
--- Formats chunks into an executable Lua script
---
---@param chunks chunk[]
---@return string
function chunker.emit_lua(chunks)
    local frags = {}
    return table.concat(frags, "\n")
end

return chunker
