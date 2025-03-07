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


---@class VertexLocation
---@field name string
---@field location number
---@field ty TypeDef

---Accumulate binding locations
---@param ty TypeDef | FunctionArg | StructMember
---@param target table<number, VertexLocation>
local function find_bound_locations(ty, target)
    if ty.binding then
        local location = ty.binding.Location
        if location then
            target[location.location] = {
                name = ty.name,
                ty = ty.ty or ty,
                location = location.location
            }
        end
    else
        local inner = ty.ty or ty
        if inner.kind == "struct" then
            ---@cast inner StructDef
            for _, member in ipairs(inner.members) do
                find_bound_locations(member, target)
            end
        end
    end
end

---comment
---@param entry FunctionDef
---@return table<number, VertexLocation>
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
---@return table<string, table<number, VertexLocation>>
function unify_vertex.find_vertex_layouts(shader)
    local layouts = {}
    for _, entry in ipairs(shader.entry_points.vertex) do
        layouts[entry.name] = find_layout(entry.func)
    end
    return layouts
end

local tests = {}
unify_vertex._tests = tests

function tests.find_layouts()
    local src1 = [[
    struct VertexInput {
        @builtin(vertex_index) vertex_index : u32,
        @location(0) position: vec3f,
        @location(1) texcoord: vec2f,
        @location(3) color: vec3f,
    };
    struct VertexOutput {
        @location(0) color : vec4f,
        @builtin(position) pos: vec4f,
    };

    @vertex
    fn vs_main(vin: VertexInput) -> VertexOutput {
        var positions = array<vec2f, 3>(
            vec2f(0.0, -0.5),
            vec2f(0.5, 0.5),
            vec2f(-0.5, 0.75),
        );
        var colors = array<vec3f, 3>(  // srgb colors
            vec3f(1.0, 1.0, 0.0),
            vec3f(1.0, 0.0, 1.0),
            vec3f(0.0, 1.0, 1.0),
        );
        let index = i32(vin.vertex_index);
        var out: VertexOutput;
        out.pos = vec4f(positions[index], 0.0, 1.0);
        out.color = vec4f(colors[index], 1.0);
        return out;
    }
    
    @vertex
    fn vs_main2(@location(0) position: vec3f, @location(1) color: vec3f) -> VertexOutput {
        var positions = array<vec2f, 3>(
            vec2f(0.0, -0.5),
            vec2f(0.5, 0.5),
            vec2f(-0.5, 0.75),
        );
        var colors = array<vec3f, 3>(  // srgb colors
            vec3f(1.0, 1.0, 0.0),
            vec3f(1.0, 0.0, 1.0),
            vec3f(0.0, 1.0, 1.0),
        );
        var out: VertexOutput;
        out.pos = vec4f(position, 1.0);
        out.color = vec4f(color, 1.0);
        return out;
    }

    @fragment
    fn fs_main(in: VertexOutput) -> @location(0) vec4f {
        let physical_color = pow(in.color.rgb, vec3f(2.2));  // gamma correct
        return vec4f(physical_color, in.color.a);
    }
    ]]
    local deepprint = require "utils.deepprint"
    local streq = require("utils.deepeq").string_equal
    local utils = require "utils.common"
    local naga = require "analysis.naga"
    local p1 = naga.parse(src1)

    local layouts = unify_vertex.find_vertex_layouts(p1)

    local layout1 = assert(layouts["vs_main"], "No layout for vs_main")
    deepprint(layout1)
    assert(#utils.keys(layout1) == 3)
    assert(streq(layout1[0].name, "position"))
    assert(streq(layout1[1].name, "texcoord"))
    assert(streq(layout1[3].name, "color"))
    assert(streq(layout1[0].ty.name, "vec3<f32>"))
    assert(streq(layout1[1].ty.name, "vec2<f32>"))
    assert(streq(layout1[3].ty.name, "vec3<f32>"))

    local layout2 = assert(layouts["vs_main2"], "No layout for vs_main2")
    assert(#utils.keys(layout2) == 2)
    assert(streq(layout2[0].name, "position"))
    assert(streq(layout2[1].name, "color"))
    assert(streq(layout2[0].ty.name, "vec3<f32>"))
    assert(streq(layout2[1].ty.name, "vec3<f32>"))
end

return unify_vertex