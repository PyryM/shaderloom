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

    local cursor = 1
    local tail = cursor
    local src_len = #src

    local frags = {}

    while cursor <= src_len do
        local pre_line = src:match("^%s*#(.*\n)", cursor)
        if pre_line then
            -- this is a preprocessor line `# ...`
            table.insert(frags, pre_line)
            cursor = (src:find("\n", cursor) or src_len) + 1
        else
            -- TODO
        end
    end

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
