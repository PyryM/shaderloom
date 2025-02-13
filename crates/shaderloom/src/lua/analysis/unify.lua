local struct_unify = require "analysis.unify.structs"
local bind_unify = require "analysis.unify.bindings"

local unify = {}

function unify.unify_host_shared_structs(shaders)
    return struct_unify.unify_host_shared_structs(shaders)
end

function unify.unify_bind_groups(shaders)
    return bind_unify.unify_bind_groups(shaders)
end

return unify