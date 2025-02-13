local unify_vertex = {}

-- binding = {
--     Location = {
--         location = [number] 0,
--         second_blend_source = [boolean] false,
--         interpolation = [string] "Perspective",
--         sampling = [string] "Center",
--     },
-- },

-- arguments = {
--     1 = {
--         name = [string] "position",
--         binding = [already printed table #107],
--         ty = [already printed table #425],
--     },
--     2 = {
--         name = [string] "input",
--         ty = {
--             kind = [string] "struct",
--             size = [number] 48,
--             members = {
--                 1 = {
--                     binding = [already printed table #382],
--                     offset = [number] 0,
--                     ty = [already printed table #425],
--                     name = [string] "color",
--                 },
--                 2 = {
--                     binding = [already printed table #385],
--                     offset = [number] 16,
--                     ty = [already printed table #425],
--                     name = [string] "normal",
--                 },
--                 3 = {
--                     binding = [already printed table #388],
--                     offset = [number] 32,
--                     ty = [already printed table #429],
--                     name = [string] "texcoord",
--                 },
--             },
--             name = [string] "VertexInput",
--         },

---Accumulate binding locations
---@param ty TypeDef | FunctionArg | StructMember
---@param target any
local function find_bound_locations(ty, target)
    if ty.binding then
        if ty.binding.Location then
            target[ty.binding.Location.location] = ty.ty or ty
        end
    elseif ty.kind == "struct" then
        ---@cast ty StructDef
        for _, member in ipairs(ty.members) do
            find_bound_locations(member, target)
        end
    end
end

---comment
---@param entry FunctionDef
local function find_layout(entry)
    local locations = {}
    for _, arg in ipairs(entry.arguments) do
        find_bound_locations(arg, locations)
    end
    return locations
end

---Find all vertex layouts as input to vertex shader stages
---(HRM... should these be correlated somehow?)
---@param shader ShaderDef
function unify_vertex.find_vertex_layouts(shader)
    local layouts = {}
    for _, entry in ipairs(shader.entry_points.vertex) do
    end
    return layouts
end

return unify_vertex