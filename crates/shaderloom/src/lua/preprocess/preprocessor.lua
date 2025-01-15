local class = require "miniclass"
local chunker = require "preprocess.chunker"

local Preprocessor = class "Preprocessor"

function Preprocessor:init(resolver)
    self.resolver = resolver
    self:clear()
end

function Preprocessor:emit_raw(src)
    src = tostring(src)
    table.insert(self.frags, src)
    self.annotation_cursor = self.annotation_cursor + #src
end

function Preprocessor:emit(src)
    self:emit_raw(src)
    --self:process_source(src) -- not sure if recursing here is a good idea
end

function Preprocessor:annotate(annotator, args)
    table.insert(self.annotations, {
        eval=annotator,
        pos=self.annotation_cursor,
        args=args
    })
end

local function identity_annotation(tab)
    return tab.category, tab.name, tab.payload
end
function Preprocessor:_pre_annotate(category, name, payload)
    table.insert(self.annotations, {
        category = category,
        name = name,
        payload = payload,
        eval = identity_annotation
    })
end

-- captures name from e.g., "var tex_whatever: texture_multisampled_2d<f32>;"
local VISIBILITY_PATT_BARE = "var%s+([^%s:]*)%s*:"
local VISIBILITY_PATT_TEMPLATE = "var%s*%b<>%s*([^%s:]*)%s*:"
local function _annotate_visibility(call_info, source)
    local end_pos = source:find(";", call_info.pos)
    local statement = source:sub(call_info.pos, end_pos)
    local var_name = assert(
        statement:match(VISIBILITY_PATT_TEMPLATE)
        or statement:match(VISIBILITY_PATT_BARE),
        "Unmatched visibility annotation"
    )
    return "visibility", var_name, call_info.args
end

local function set(items)
    local s = {}
    for _, item in ipairs(items) do
        s[item] = true
    end
    return s
end

function Preprocessor:annotate_visibility(...)
    -- handle calling both as 
    -- visibility("fragment", "vertex") and
    -- visibility{"fragment", "vertex"}
    local args = {...}
    if #args == 1 and type(args[1]) == 'table' then
        args = args[1]
    end
    self:annotate(_annotate_visibility, set(args))
end

local bind_helper_mt = {}
bind_helper_mt.__index = bind_helper_mt
function bind_helper_mt:__tostring() return tostring(self.id) end
function bind_helper_mt:binding(bind)
    self.ctx:emit_raw(("@group(%d) @binding(%d)"):format(self.id, bind))
end

function Preprocessor:annotate_bindgroup(args)
    assert(type(args) == "table", "bindgroup{} expects a table argument!")
    local id = assert(args.id or args[1], "missing .id in bindgroup{...}!")
    local name = args.name or ("bindgroup_" .. id)
    local shared = not not args.shared
    self:_pre_annotate("bindgroups", name, {id=id, name=name, shared=shared})
    return setmetatable({id=id, ctx=self}, bind_helper_mt)
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
    self.annotation_cursor = 1
    self.annotations = {}
    self.env = {
        emit = self:_bind("emit"),
        emit_raw = self:_bind("emit_raw"),
        include = self:_bind("include"),
        visibility = self:_bind("annotate_visibility"),
        bindgroup = self:_bind("annotate_bindgroup"),
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
    local output = table.concat(self.frags, "")
    local annotations = {visibility={}, bindgroups={}}
    for _, annotator in ipairs(self.annotations) do
        local category, name, annotation = annotator:eval(output)
        if category and name then
            annotations[category][name] = annotation
        end
    end
    return output, annotations
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
    local eq = require("utils.deepeq").string_equal
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

function tests.only_preprocessor()
    local dedent = require("utils.stringmanip").dedent
    local eq = require("utils.deepeq").string_equal
    local files = {
        MAIN=dedent[[
        # 
        # 
        # emit_raw "asdf"
        # thing = 12
        # ]]
    }
    local expected = "asdf"
    local translated = test_proc(files)
    assert(eq(expected, translated))
end

function tests.inline_translation()
    local dedent = require("utils.stringmanip").dedent
    local eq = require("utils.deepeq").string_equal
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

function tests.includes()
    local dedent = require("utils.stringmanip").dedent
    local eq = require("utils.deepeq").string_equal
    local files = {
        MAIN=dedent[[
        #include "other"
        fn eh() {
        }
        ]],
        other=dedent[[
        @compute @workgroup_size(1)
        ]]
    }
    local expected = dedent[[
    @compute @workgroup_size(1)
    fn eh() {
    }
    ]]
    local translated = test_proc(files)
    assert(eq(expected, translated))
end

function tests.visibility_annotation()
    local deq = require("utils.deepeq").dict_exact_equal
    local seq = require("utils.deepeq").string_equal
    assert(seq(
        ("var < workgroup > foo : u32"):match(VISIBILITY_PATT_TEMPLATE, 1),
        "foo"
    ))
    assert(seq(
        ("var tex_whatever: texture_2d<f32>;"):match(VISIBILITY_PATT_BARE, 1),
        "tex_whatever"
    ))

    local dedent = require("utils.stringmanip").dedent
    local files = {
        MAIN=dedent[[
        # visibility "fragment"
        var < workgroup > foo : u32;
        # visibility("fragment", "vertex")
        var tex_whatever: texture_2d<f32>;
        # visibility{"vertex"}
        @binding(0) @group(12)
        var<storage, read_write > v_ehhhh_32 : array<f32>;
        ]],
    }
    local _translated, annotations = test_proc(files)
    assert(deq(annotations.visibility.foo, {fragment=true}))
    assert(deq(annotations.visibility.tex_whatever, {fragment=true, vertex=true}))
    assert(deq(annotations.visibility.v_ehhhh_32, {vertex=true}))
end

function tests.bindgroup_annotation()
    local deq = require("utils.deepeq").dict_exact_equal
    local seq = require("utils.deepeq").string_equal

    local dedent = require("utils.stringmanip").dedent
    local files = {
        MAIN=dedent[[
        # bindgroup{0, name="uniforms", shared=true}
        # FOOBAR = bindgroup{
        #   id=2,
        #   name="foobar"
        # }
        @group(${{FOOBAR}})
        # FOOBAR:binding(3)
        ]],
    }
    local translated, annotations = test_proc(files)
    assert(seq(translated, "@group(2)\n@group(2) @binding(3)"))
    assert(deq(annotations.bindgroups.uniforms, {id=0, name="uniforms", shared=true}))
    assert(deq(annotations.bindgroups.foobar, {id=2, name="foobar", shared=false}))
end

return {
    Preprocessor = Preprocessor,
    _tests = tests
}