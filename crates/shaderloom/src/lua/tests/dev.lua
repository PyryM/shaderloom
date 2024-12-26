local deep_print = require "utils.deepprint"
local preprocess = require "preprocess.preprocessor"

local files = {
    ["test_file_two.wgsl"] = [[
// This should get emitted!
# function some_macro(arg)
#  return ("vec3f(%s, %s, %s)"):format(arg, arg, arg)
# end
]],
    ["test_file_one.wgsl"] = [[
# include "test_file_two.wgsl"
# THING = true
]],
    ["test_main.wgsl"] = [[
# include "test_file_one.wgsl"
# if THING then
@fragment frag_main(frag_in: VertexOutput) -> vec3f {
    return ${{some_macro("12")}}
}
# else
// THING was not set!
# end
]],
    ["collatz.wgsl"] = [[
struct Hmm {
    x: vec4f,
    y: vec3f,
    z: vec2f,
    a: mat4x4f,
    b: f32,
    d: u32,
    e: i32,
}
struct PrimeIndices {
    erm: array<Hmm, 100>,
    data: array<u32>
} // this is used as both input and output for convenience

@group(0) @binding(0)
var<storage,read_write> v_indices: PrimeIndices;

@group(0) @binding(1)
var tex_whatever: texture_multisampled_2d<f32>;

@group(0) @binding(2)
var samp_a: sampler;

@group(0) @binding(3)
var samp_b: sampler_comparison;

@group(0) @binding(4)
var<storage, read_write> atomic_array: array<atomic<u32>>;

// The Collatz Conjecture states that for any integer n:
// If n is even, n = n/2
// If n is odd, n = 3n+1
// And repeat this process for each new n, you will always eventually reach 1.
// Though the conjecture has not been proven, no counterexample has ever been found.
// This function returns how many times this recurrence needs to be applied to reach 1.
fn collatz_iterations(n_base: u32) -> u32 {
    var n = n_base;
    var i: u32 = 0u;
    while n > 1u {
        if n % 2u == 0u {
            n = n / 2u;
        }
        else {
            n = 3u * n + 1u;
        }
        i = i + 1u;
    }
    return i;
}

@compute @workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    v_indices.data[global_id.x] = collatz_iterations(v_indices.data[global_id.x]);
}
]]
}
local resolver = function(name)
    return assert(files[name], "Missing " .. name)
end

local function main()
    local processor = preprocess.Preprocessor(resolver)

    processor:include("test_main.wgsl")
    local res = processor:get_output()
    print("------")
    print(res)

    processor:clear()
    processor:include("collatz.wgsl")
    local src = processor:get_output()

    local naga = require "analysis.naga"
    local parsed = naga.parse(src)
    deep_print(parsed.types)

    error("eh")
end

return main