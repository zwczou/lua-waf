--!/usr/bin/lua


local path = require "path"

local open = io.open
local setmetatable = setmetatable


_M = {
  _VERSION = "0.01"
}

local function trim(str)
  return str:gsub("%s+", "")
end

local function toboolean(str)
  return str == "true" or str == "on"
end

local number_keys = { 
  cc_rate = true,
  cc_duration = true
}

local string_keys = {
  cc_store_key = true,
  redirect_url = true,
  content = true
}

function _M.load(self, filepath)
  local fp = open(filepath, 'r')
  if not fp then
    return nil, "not found config filepath"
  end
  self.filepath = filepath
  self.dirname = path:dirname(filepath)

  local count = 0
  for line in fp:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local k, v = line:match("([^=]+)%s?=%s?([^#]+)%s?")
      if k and v then
        k, v = trim(k), trim(v)
        if number_keys[k] then
          v = tonumber(v)
        elseif string_keys[k] then
          v = v:gsub('"', ""):gsub("'", "")
        else
          v = toboolean(v)
        end
        self[k] = v
        count = count + 1
      end
    end
  end
  fp:close()

  self['content'] = self:get_content()
  return count
end

function _M.get_content(self)
  local fp = open(self.content, 'r')
  if not fp then
    local filepath = path:join(self.dirname, self.content)
    fp = open(filepath, 'r')
  end

  local content
  if fp then
    content = fp:read("*a")
    fp:close()
  end
  return content or self.content or 'waf'
end

function _M.get_rule(self, filepath)
  local fp = open(filepath, 'r')
  if not fp then
    filepath = path:join(self.dirname, filepath)
    fp = open(filepath, 'r')
  end

  if not fp then
    return nil, "not found rule filepath"
  end

  local rules = {}
  for line in fp:lines() do
    if #line > 0 then
      rules[#rules + 1] = line
    end
  end
  fp:close()

  return rules
end

return _M
