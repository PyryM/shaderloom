use "config.declarative"

target "rust.wgpu" {
    validate = true,
    struct_definitions = {
        output = "${SCRIPTDIR}/shader_structs.rs",
        field_decorator = function(field, _ty)
            -- add PyO3 getter/setter annotations to fields
            field.comment = "/// A field visible to python!"
            if not field.is_padding then
                field.derive = "#[pyo3(get, set)]"
            end
        end,
        struct_decorator = function(struct)
            -- annotate this as a PyO3 class
            struct.comment = "/// A fun struct visible to python!"
            struct.derive = "#[derive(Copy, Clone, Pod, Zeroable)]\n#[pyclass]"
        end
    },
}

include_dirs "${SCRIPTDIR}/include"

add_shaders "${SCRIPTDIR}/*.wgsl"
