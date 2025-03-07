local struct_unify = require "analysis.unify.structs"
local bind_unify = require "analysis.unify.bindings"
local vertex_unify = require "analysis.unify.vertex"

local utils = require "utils.common"

local unify = {}

unify.unify_host_shared_structs = struct_unify.unify_host_shared_structs
unify.unify_bind_groups = bind_unify.unify_bind_groups
unify.find_vertex_layouts = vertex_unify.find_vertex_layouts

function unify.unify_vertex_layouts(shaders)
    error("NYI!")
end

unify._tests = utils.merge(
    struct_unify._tests,
    bind_unify._tests,
    vertex_unify._tests
)

return unify