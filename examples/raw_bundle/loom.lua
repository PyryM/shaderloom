use "config.declarative"

target "raw" {
    bundle = {
        bundle_template = ([[
        local shaders = {}
        ${SHADERS}
        return shaders
        ]]):dedent(),
        shader_template = "shaders['${NAME}'] = [[${SOURCE}]]\n"
    },
    validate = true,
    output = "${SCRIPTDIR}/shaderbundle.lua",
}

include_dirs "${SCRIPTDIR}/include"

add_shaders "${SCRIPTDIR}/*.wgsl"
