local deepeq = {}

function deepeq.debug_string_format(s)
    return s:gsub(" ", "."):gsub("\n", "\\n")
end

function deepeq.streq(a, b)
    if a == b then return true end
    return false, ('"%s" ~= "%s"'):format(
        deepeq.debug_string_format(a),
        deepeq.debug_string_format(b)
    )
end

function deepeq.equals(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        if a == b then return true end
        return false, ("%s ~= %s"):format(a, b)
    else
        -- tables?
        error("Table equality NYI!")
    end
end

function deepeq.list_equal(a, b)
    if #a ~= #b then
        return false, ("Lists are different lengths: %d vs %d"):format(#a, #b)
    end
    for idx = 1, #a do
        local eq, reason = deepeq.equals(a[idx], b[idx])
        if not eq then
            return false, ("a[%d] ~= b[%d]: %s"):format(idx, idx, reason)
        end
    end
    return true
end

return deepeq