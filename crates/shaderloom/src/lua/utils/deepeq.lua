local deepeq = {}

function deepeq.debug_string_format(s)
    return s:gsub(" ", "."):gsub("\n", "\\n")
end

function deepeq.streq(a, b)
    if a == b then return true end
    if type(a) ~= "string" or type(b) ~= "string" then
        return false, "not strings"
    end
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

-- tests if b is *at least* a, but with possibly extra fields
function deepeq.dict_superset_equal(a, b)
    if type(a) ~= "table" then
        return false, "a is not table: " .. type(a)
    elseif type(b) ~= "table" then
        return false, "b is not table: " .. type(b)
    end
    for k, v in pairs(a) do
        local eq, reason = deepeq.equals(v, b[k])
        if not eq then
            return false, ("a[%s] ~= b[%s]: %s"):format(k, k, reason)
        end
    end
    return true
end

function deepeq.dict_exact_equal(a, b)
    local eq, reason = deepeq.dict_superset_equal(a, b)
    if not eq then return eq, reason end
    eq, reason = deepeq.dict_superset_equal(b, a)
    if not eq then return eq, reason end
    return true
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