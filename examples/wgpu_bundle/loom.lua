use "config.declarative"

target "rust.wgpu" {
    bundle = "${SCRIPTDIR}/shader_structs.rs",
    validate = true,
}

include_dirs "${SCRIPTDIR}/include"

add_shaders "${SCRIPTDIR}/*.wgsl"
