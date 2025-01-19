-- utils.common
--
-- just some common things?

local utils = {}

-- concatenate two list-like tables into a new table
function utils.concat(left, right)
    local ret = {}
    local left_count = #left
    local right_count = #right
    for idx = 1, left_count do
        ret[idx] = left[idx]
    end
    for idx = 1, right_count do
        ret[idx + left_count] = right[idx]
    end
    return ret
end

-- merge any number of tables into a target table,
-- modifying the target in place.
-- for duplicated keys, last wins
function utils.merge_into(target, ...)
    for arg_idx = 1, select('#', ...) do
        for k, v in pairs(select(arg_idx, ...)) do
            target[k] = v
        end
    end
    return target
end

-- merge any number of tables into a new table
-- for duplicated keys, last wins
function utils.merge(...)
    return utils.merge_into({}, ...)
end

local _concat = utils.concat
local function _curry(argcount, func, args)
    if argcount <= 0 then
        return func(unpack(args))
    else
        return function(nextarg)
            return _curry(argcount-1, func, _concat(args, {nextarg}))
        end
    end
end

-- turn a function of n args into a curried function
-- e.g.
-- function original(a, b, c) --... end
-- res = original(1, 2, 3)
-- curried = utils.curry(3, original)
-- res = curried(1) (2) (3)
function utils.curry(argcount, func)
    return _curry(argcount, func, {})
end

---create a new list by applying a function to each element
---@param items any[]
---@param func fun(item: any, idx: number): any
---@return any[]
function utils.map(items, func)
    local mapped = {}
    for idx, item in ipairs(items) do
        mapped[idx] = func(item, idx)
    end
    return mapped
end

-- create a zero-argument function that returns a constant
-- if the constant is a table, then each call returns a new shallow copy
function utils.constant(v)
    if type(v) == 'table' then
        return function() return utils.merge({}, v) end
    else
        return function() return v end
    end
end

-- check whether a value can be called like a function
function utils.is_callable(v)
    local vt = type(v)
    if vt == 'table' then
        local mt = getmetatable(v)
        return mt and mt.__call ~= nil
    else
        -- assume any userdata is callable?
        return vt == 'function' or vt == 'userdata'
    end
end

---create a table where keys are lazily populated
---with the default value
---@param default (fun(key: string?): any) | any
---@return table
function utils.default_table(default)
    if not utils.is_callable(default) then
        default = utils.constant(default)
    end
    return setmetatable({}, {
        __index = function(t, k)
            local v = default(k)
            t[k] = v
            return v
        end
    })
end

-- create a table that looks up keys in the inputs
-- starting from left to right until the key is found
function utils.cascaded_table(...)
    local tables = {...}
    return setmetatable({}, {
        __index = function(_, k)
            for _, tab in ipairs(tables) do
                local v = tab[k]
                if v then return v end
            end
        end
    })
end

local tests = {}
utils._tests = tests

function tests.default_table()
    local t = utils.default_table({})
    t.asdf[10] = 100
    assert(t.asdf[10])
    assert(t.foobar)
    assert(t.foobar ~= t.barfoo)
end

function tests.concat()
    local leq = require("utils.deepeq").list_equal
    assert(leq(utils.concat({1,2,3}, {4}), {1,2,3,4}))
end

function tests.curry()
    local curried = utils.curry(3, function(a, b, c)
        return a .. b .. c
    end)

    local res1 = curried "hello" "world" [[asdf]]
    local partial = curried "goodbye" "world"
    local res2 = partial "?"
    local res3 = partial "!"

    local streq = require("utils.deepeq").string_equal
    assert(streq(res1, "helloworldasdf"))
    assert(streq(res2, "goodbyeworld?"))
    assert(streq(res3, "goodbyeworld!"))
end

function tests.curry2()
    local curried = utils.curry(3, function(a, b, c)
        local ret = a .. b.name .. c:strip()
        return {
            with = function(_self, eh)
                return eh .. ret
            end
        }
    end)
    local res = curried "some_func" {name='foo'} [[
        wow!
    ]]:with("asdf")

    local streq = require("utils.deepeq").string_equal
    assert(streq(res, "asdfsome_funcfoowow!"))
end

return utils