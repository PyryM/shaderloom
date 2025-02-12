use "config.declarative"

target "python.xgpu" {
    bundle = "${SCRIPTDIR}/shaderbundle.py",
    validate = true,
}

include_dirs "${SCRIPTDIR}/include"

add_shaders "${SCRIPTDIR}/*.wgsl"
