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
    local chunk = assert(loadstring_env(translated, name, self.env))
    chunk()
end

function Preprocessor:get_output()
    for _, v in ipairs(self.frags) do
        print('"' .. v .. '"')
    end
    return table.concat(self.frags, "")
end

local tests = {}

local function test_proc(files)
    local resolver = function(name)
        return assert(files[name], "Missing " .. name)
    end
    local pp = Preprocessor(resolver)
    pp:include("MAIN")
    return pp:get_output()
end

function tests.identity_translation()
    local dedent = require("utils.stringmanip").dedent
    local eq = require("utils.deepeq").streq
    local files = {
        MAIN=dedent[[
        @compute @workgroup_size(1)
        fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
            v_indices.data[global_id.x] = collatz_iterations(v_indices.data[global_id.x]);
        }
        ]]
    }
    local translated = test_proc(files)
    assert(eq(files.MAIN, translated))
end

function tests.inline_translation()
    local dedent = require("utils.stringmanip").dedent
    local eq = require("utils.deepeq").streq
    local files = {
        MAIN=dedent[[
        # function one() 
        #   return 1
        # end
        @compute @workgroup_size(${{one()}})
        #-- a preprocessor comment
        fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
            v_indices.data[global_id.x] = collatz_iterations(v_indices.data[global_id.x]);
        }
        ]]
    }
    local expected = dedent[[
    @compute @workgroup_size(1)
    fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
        v_indices.data[global_id.x] = collatz_iterations(v_indices.data[global_id.x]);
    }
    ]]
    local translated = test_proc(files)
    assert(eq(expected, translated))
end

return {
    Preprocessor = Preprocessor,
    _tests = tests
}