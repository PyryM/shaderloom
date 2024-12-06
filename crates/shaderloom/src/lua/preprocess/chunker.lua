-- does a thing

local chunker = {}

---
--- Translate source into a runnable Lua script
---
---@param src string
---@return string
function chunker.translate_source(src)
    local chunks = {}

    local cursor = 1
    local tail = cursor
    local src_len = #src

    local frags = {}

    while cursor <= src_len do
        local pre_line = src:match("^%s*#([^\n]*)\n", cursor)
        if pre_line then
            -- this is a preprocessor line `# ...`
            -- preprocessor lines are inserted verbatim
            table.insert(frags, pre_line) 
            cursor = (src:find("\n", cursor) or src_len) + 1
        else
            -- not a preprocessor line, so find the next preprocessor line
            local start = cursor
            cursor = (src:find("\n%s*#", cursor) or src_len)
            local shader_src = src:sub(start, cursor)
            table.insert(frags, ("emit_raw[[%s]]"):format(shader_src))
            cursor = cursor + 1
        end
    end

    return table.concat(frags, "\n")
end

return chunker
