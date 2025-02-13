struct ViewUniforms {
    @align(16) view_mat: mat4x4f,
    @align(16) proj_mat: mat4x4f,
}

struct Uniforms {
    @align(16) model_mat: mat4x4f,
    @align(16) normal_mat: mat4x4f,
    @align(16) tex_params: vec4f,
}

@group(0) @binding(0) var<uniform> view_uniforms: ViewUniforms;

@group(1) @binding(0) var<uniform> uniforms: Uniforms;
@group(1) @binding(1) var matcap: texture_2d<f32>;
@group(1) @binding(2) var diffuse: texture_2d<f32>;
@group(1) @binding(3) var samp: sampler;

struct VertexInput {
    @location(1) color: vec3f,
    @location(2) normal: vec3f,
    @location(3) texcoord: vec2f
}

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) view_pos: vec3f,
    @location(1) view_normal: vec3f,
    @location(2) color: vec3f,
    @location(3) texcoord: vec2f,
}

@vertex
fn vs_main(@location(0) position : vec3f, input: VertexInput) -> VertexOutput {
    let world_pos = uniforms.model_mat * vec4f(position.xyz, 1.0f);
    let world_normal = uniforms.normal_mat * vec4f(input.normal.xyz, 0.0f);
    let view_normal = view_uniforms.view_mat * world_normal;
    let view_pos = view_uniforms.view_mat * world_pos;
    let outpos = view_uniforms.proj_mat * view_pos;
    return VertexOutput(outpos, view_pos.xyz, view_normal.xyz, input.color.rgb, input.texcoord.xy);
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    let tex_params = uniforms.tex_params;
    var normal: vec3f = vec3f(0.0);
    if tex_params.z > 0.0 {
        // faceted: compute normal from screen-space derivatives
        normal = normalize(cross(dpdx(input.view_pos), dpdy(input.view_pos)));
    } else {
        // smooth shaded
        normal = normalize(input.view_normal);
    }
    let ns = normal.xy * 0.99;
    var samppos: vec2f = (ns + vec2f(1.0)) * 0.5;
    samppos.y = 1.0 - samppos.y;
    var outcolor: vec3f = textureSample(matcap, samp, samppos).rgb;
    if tex_params.x > 0.0 {
        let diffusecolor = textureSample(diffuse, samp, input.texcoord).rgb;
        outcolor *= diffusecolor;
    }
    if tex_params.y > 0.0 {
        outcolor *= input.color.rgb;
    }

    return vec4f(pow(outcolor.rgb, vec3f(2.2)), 1.0);
}