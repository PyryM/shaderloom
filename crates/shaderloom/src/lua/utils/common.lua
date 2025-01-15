-- utils.common
--
-- just some common things?

local utils = {}

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

return utils