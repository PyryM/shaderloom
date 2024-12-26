local function format_primitive(val)
    local vt = type(val)
    if vt == "string" then
        return '[string] "' .. val .. '"'
    elseif vt == "userdata" and val == null then
        return '[null]'
    else
        return ("[%s] %s"):format(vt, tostring(val))
    end
end

local function _deep_print(seen, printer, indent, key, val)
    if type(val) ~= "table" then
        printer(indent, ("%s = %s,"):format(key, format_primitive(val)))
        return
    end
    if seen[val] then
        printer(indent, ("%s = [already printed %s],"):format(key, seen[val]))
        return
    end
    seen[val] = ("table #%d"):format(seen.count)
    seen.count = seen.count + 1
    printer(indent, ("%s = {"):format(key))
    local max_idx_printed = #val
    for idx = 1, max_idx_printed do
        _deep_print(printer, indent+1, idx, val[idx])
    end
    for k, v in pairs(val) do
        if type(k) ~= "number" or k <= 0 or k > max_idx_printed then
            _deep_print(printer, indent+1, k, v)
        end
    end
    printer(indent, "},")
end

local function deep_print(v)
    local function printer(indent, v)
        print((" "):rep(indent*4) .. tostring(v))
    end
    _deep_print(printer, 0, "VAL", v)
end

return deep_print