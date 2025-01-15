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

local function block(name)
    return function(children)

    end
end