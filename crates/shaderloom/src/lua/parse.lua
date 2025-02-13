-- entrypoint that exists so you can call
-- shaderloom run parse some_file.wgsl

local parse = {}
local naga = require "analysis.naga"
local fileio = require "utils.fileio"
local deepprint = require "utils.deepprint"

---Main entry point of info module
---@param arg string?
function parse.main(arg)
    if not arg then
        print(("No source wgsl file specified!"):red())
        return
    end
    local source = fileio.read(arg)
    local parsed = naga.parse(source)
    deepprint(parsed)
end

return parse