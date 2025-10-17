use "config.declarative"

local PYO3_NEW_TEMPLATE = [[
/// (pymethods) ${NAME}
#[pymethods]
impl ${NAME} {
    #[new]
    pub fn new(${ARGS}) -> Self {
        Self {
            ${ARGVARS}
            ..Self::zeroed()
        }
    }
}
]]

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
        end,
        struct_impl = function(struct)
            -- produce a "new" for PyO3
            local args = {}
            local argvars = {}
            for _, field in ipairs(struct.fields) do
                if not field.is_padding then
                    table.insert(args, ("%s: %s, "):format(field.name, field.tyname))
                    table.insert(argvars, field.name .. ",")
                end
            end
            return PYO3_NEW_TEMPLATE:with{
                ARGS=table.concat(args, ""),
                ARGVARS=table.concat(argvars, ""),
                NAME=struct.name
            }
        end
    },
}

include_dirs "${SCRIPTDIR}/include"

add_shaders "${SCRIPTDIR}/*.wgsl"
