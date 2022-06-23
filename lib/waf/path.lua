--!/usr/bin/lua


local concat = table.concat
local setmetatable = setmetatable

_M = {
  _VERSION = '0.01'
}

mt = {
  __index = _M
}

function _M.split(self, filepath)
  return filepath:match("^(.-)[\\/]?([^\\/]*)$")
end

function _M.dirname(self, filepath)
  return (self:split(filepath))
end

function _M.basename(self, filepath)
  local _, name = self:split(filepath)
  return name
end

function _M.join(self, dirname, basename)
  local res = {}

  if dirname then
    res[#res + 1] = dirname
  end
  res[#res + 1] = basename

  return concat(res, "/")
end

return setmetatable(_M, mt)
