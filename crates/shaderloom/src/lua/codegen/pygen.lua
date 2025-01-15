-- codegen.pygen
--
-- utils for more easily generating python code

-- pyclass "whatever" {
--   def("__init__", {name="int"}, [[
--     erm
--     whatever
--     foo
--   ]]:with{})
-- }

-- kwcall(builder .. ".add_buffer", {
--   binding=bind.binding,
--   visibility=make_vis(bind),
--   sampletype=texSampleType(bind.sampleType),
--   viewdim=texViewDim(bind.dimension)
-- })

-- function create_pipeline(shader)
--     -- TODO?
--     return def "create_pipeline" {
--         "self", "primitive: xg.PrimitiveState", "targets: list[xg.ColorTargetState]",
--         "depth_stencil: Optional[xg.DepthStencilState]=None", 
--         "multisample: Optional[xg.MultisampleState]=None"} ([=[
--             assert len(targets) == ${output_count}
--             if multisample is None:
--                 multisample = xg.multisampleState()
--             self.pipeline = self.device.createRenderPipeline(
--                 layout=self.pipeline_layout,
--                 vertex=xg.vertexState(
--                     module=self.shader_module,
--                     entryPoint="${vs_entry}",
--                     constants=[],
--                     buffers=[${buffers}],
--                 ),
--                 primitive=primitive,
--                 depthStencil=depth_stencil,
--                 multisample=multisample,
--                 fragment=xg.fragmentState(
--                     module=self.shader_module,
--                     entryPoint="${fs_entry}",
--                     constants=[],
--                     targets=targets,
--                 ),
--             )
--         ]=]:with{
--             vs_entry=vs_entry,
--             fs_entry=fs_entry,
--             output_count=output_count,
--             buffers=buffers
--         })
-- end

class(baseName) {
    def "__init__" {"self", "device: XDevice", "source: Optional[str]=None"} [=[
        self.device = device
        self.bind_groups: list[Optional[xg.BindGroup]] = [None] * ${bg_count}
        self.binders = []
        self._create_bindgroup_layouts()
        self._create_pipeline_layout()
        if source is None:
            source = ${source_name}
        self.shader_module = self.device.createWGSLShaderModule(
            label=${label}
            code=source
        )
    ]=]:with{
        bg_count = bindgroups.length,
        source_name = source_name,
        label = strlit(rawName)
    },
    create_pipeline(shader)
}

local function block(name)
    return function(children)

    end
end