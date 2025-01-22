-- info
--
-- a module that exists just so you can call "shaderloom run info"

local info = {}

---Main entry point of info module
---@param arg string?
function info.main(arg)
    local color_arg = (arg and arg:magenta()) or ("nil"):red()
    print("You have called", ("info"):cyan(), "with the argument", color_arg)
end

return info