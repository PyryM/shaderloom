-- does a thing

local chunker = {}

local function emit_raw(frags, src)
    if src:sub(1,1) == "\n" then
        -- quirk with first newline of multiline strings being ignored
        src = "\n" .. src
    end
    table.insert(frags, ("emit_raw[[%s]]"):format(src))
end

local function emit(frags, src)
    table.insert(frags, ("emit(%s)"):format(src))
end

local function handle_source(src, frags)
    local cursor = 1
    local src_len = #src
    while cursor <= src_len do
        local start = cursor
        cursor = src:find("${{", cursor)
        if cursor then
            local subssrc = src:sub(start, cursor-1)
            if #subssrc > 0 then
                emit_raw(frags, subssrc)
            end
            local macro_end = assert(src:find("}}", cursor+3), "Unclosed macro!")
            local macro_src = src:sub(cursor+3, macro_end-1)
            emit(frags, macro_src)
            cursor = macro_end + 2
        else -- no interpolations, emit remainder of source    
            local subssrc = src:sub(start, src_len)
            emit_raw(frags, subssrc)
            break
        end
    end
end

---
--- Translate source into a runnable Lua script
---
---@param src string
---@return string
function chunker.translate_source(src)
    local cursor = 1
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
            handle_source(shader_src, frags)
            cursor = cursor + 1
        end
    end

    return table.concat(frags, "\n")
end

return chunker
