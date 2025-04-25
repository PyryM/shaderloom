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
        local macro_start, macro_end, macro_expr = src:find("$(%b{})", cursor)
        if macro_start then
            if macro_start > start then
                -- emit the source up to the start of the macro
                emit_raw(frags, src:sub(start, macro_start-1))
            end
            -- strip {} surrounding macro expression
            emit(frags, macro_expr:sub(2, #macro_expr-1))
            cursor = macro_end + 1
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
    -- because we're operating on a line-by-line basis we
    -- need the source to end in a newline.
    if src:sub(#src, #src) ~= "\n" then src = src .. "\n" end
    local src_len = #src

    local frags = {}

    while cursor <= src_len do
        local match_start, match_end, pre_line = src:find("^%s*#([^\n]*)\n", cursor)
        if match_start then
            -- this is a preprocessor line `# ...`
            -- preprocessor lines are inserted verbatim
            table.insert(frags, pre_line)
            cursor = match_end + 1
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
