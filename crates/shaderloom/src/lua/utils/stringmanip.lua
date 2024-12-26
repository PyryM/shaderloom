local stringmanip = {}

-- Split text into a list consisting of the strings in text,
-- separated by strings matching delimiter (which may be a pattern).
-- example: strsplit(",%s*", "Anna, Bob, Charlie,Dolores")
-- (from http://lua-users.org/wiki/SplitJoin)
function stringmanip.split(text, delimiter)
    local parts = {}
    local pos = 1
    delimiter = delimiter or "\n"
    if (""):find(delimiter) then -- this would result in endless loops
        error("delimiter matches empty string!")
    end
    while true do
        local first, last = text:find(delimiter, pos)
        if first then -- found?
            table.insert(parts, text:sub(pos, first-1))
            pos = last+1
        else
            table.insert(parts, text:sub(pos))
            break
        end
    end
    return parts
end

-- trims whitespace around a string
-- 'trim5' from: http://lua-users.org/wiki/StringTrim
function stringmanip.strip(str)
  return str:match'^%s*(.*%S)' or ''
end

local function common_indent(lines)
    local indent = math.huge
    for _, line in ipairs(lines) do
        if not line:match("^%s*$") then
            local prefix = line:match("^(%s*)")
            indent = math.min(indent, #prefix)
        end
    end
    return indent
end

function stringmanip.dedent(block)
    local lines = stringmanip.split(block)
    local indent = common_indent(lines)
    for idx = 1, #lines do
        lines[idx] = lines[idx]:sub(indent+1)
    end
    return table.concat(lines, "\n")
end

local tests = {}
stringmanip._tests = tests

function tests.split()
    local list_eq = require("utils.deepeq").list_equal
    local lines = {
        "",
        "   foo   ",
        "bar",
        "",
        "baz",
        ""
    }
    assert(list_eq(
        lines,
        stringmanip.split(table.concat(lines, "\n"))
    ))
end

function tests.dedent()
    local block = [[
    Foo

    Bar

    Baz
        Bazingo

        Blorbo
    Boingo]]
    local expected = table.concat({
        "Foo",
        "",
        "Bar",
        "",
        "Baz",
        "    Bazingo",
        "",
        "    Blorbo",
        "Boingo"
    }, "\n")
    local eq = require("utils.deepeq").streq
    assert(eq(expected, stringmanip.dedent(block)))
end

return stringmanip