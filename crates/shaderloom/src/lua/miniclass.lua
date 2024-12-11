local m = {}

local unpack = unpack or table.unpack

local class_mt_mt = {}
function class_mt_mt.__call(cls, ...)
  local instance = setmetatable({}, cls)
  instance:init(...)
  return instance
end

function m.class(name)
  local mt = setmetatable({classname=name}, class_mt_mt)
  mt.__index = mt
  return mt
end

function m.extend(cls, name)
  local mt = {}
  for k, v in pairs(cls) do
    mt[k] = v
  end
  mt.classname = name
  mt.__index = mt
  setmetatable(mt, class_mt_mt)
  return mt
end

-- allow just using the module itself as a callable
setmetatable(m, {
    __call = function(_, name)
        return m.class(name)
    end
})

return m