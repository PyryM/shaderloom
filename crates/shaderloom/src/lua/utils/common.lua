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

function utils.merge_into(target, ...)
    for arg_idx = 1, select('#', ...) do
        for k, v in pairs(select(arg_idx, ...)) do
            target[k] = v
        end
    end
    return target
end

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

function utils.curry(argcount, func)
    return _curry(argcount, func, {})
end

function utils.constant(v)
    if type(v) == 'table' then 
        return function() return utils.merge({}, v) end
    else
        return function() return v end
    end
end

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