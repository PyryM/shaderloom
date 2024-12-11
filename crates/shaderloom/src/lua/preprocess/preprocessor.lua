local class = require "miniclass"
local chunker = require "preprocess.chunker"

local Preprocessor = class "Preprocessor"

function Preprocessor:init(resolver)
    self.resolver = resolver
    self:clear()
end

function Preprocessor:emit(src)
    table.insert(self.frags, src)
    --self:process_source(src) -- not sure if recursing here is a good idea
end

function Preprocessor:emit_raw(src)
    table.insert(self.frags, src)
end

function Preprocessor:include(name)
    self:process_source(self.resolver(name), name)
end

function Preprocessor:_bind(name)
    local func = assert(self[name], "Missing bind! " .. name)
    return function(...)
        return func(self, ...)
    end
end

function Preprocessor:clear()
    self.frags = {}
    self.env = {
        emit = self:_bind("emit"),
        emit_raw = self:_bind("emit_raw"),
        include = self:_bind("include")
    }
    setmetatable(self.env, {
        __index = _G
    })
end

function Preprocessor:process_source(source, name)
    local translated = chunker.translate_source(source)
    print("TRANSLATED: vvvvvv", name)
    print(translated)
    print("^^^^^^^^")
    local chunk = assert(loadstring_env(translated, name, self.env))
    chunk()
end

function Preprocessor:get_output()
    for _, v in ipairs(self.frags) do
        print('"' .. v .. '"')
    end
    return table.concat(self.frags, "")
end

return {
    Preprocessor = Preprocessor
}