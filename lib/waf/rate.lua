--!/usr/bin/lua


local ffi = require "ffi"
local math = require "math"

local ngx_now = ngx.now
local ngx_shared = ngx.shared
local ffi_cast = ffi.cast
local ffi_str = ffi.string
local min = math.min
local floor = math.floor
local setmetatable = setmetatable
local assert = assert


ffi.cdef[[
  struct lua_rate_rec {
    double last;
    unsigned int allowance;
  };
]]

local const_rec_ptr_type = ffi.typeof("const struct lua_rate_rec*")
local rec_size = ffi.sizeof("struct lua_rate_rec")
local rec_cdata = ffi.new("struct lua_rate_rec")


_M = {
  _VERSION = '0.01'
}

mt = {
  __index = _M
}


function _M.new(dict_name, rate, duration)
  local dict = ngx_shared[dict_name]
  if not dict then
    return nil, "shared dict not found"
  end

  assert(rate > 0 and duration > 0)

  local self = {
    dict = dict,
    rate = rate,
    duration = duration,
  }
  return setmetatable(self, mt)
end

-- local delay, remaining, err = ratelimit:limit(key)
function _M.limit(self, key)
  local dict = self.dict
  local rate = self.rate
  local duration = self.duration
  local now = ngx_now()

  local allowance = rate
  local delay = 0

  local v = dict:get(key)
  if v then
    if type(v) ~= "string" or #v ~= rec_size then
      return nil, nil, "shared dict abused by other users"
    end

    local rec = ffi_cast(const_rec_ptr_type, v)
    local elapsed = now - tonumber(rec.last)
    allowance = tonumber(rec.allowance) + (elapsed * rate / duration)
    allowance = min(allowance, rate)
  end

  if allowance >= 1 then
    allowance = allowance - 1
  else
    delay = (1 - allowance) * (duration / rate)
  end

  rec_cdata.last = now
  rec_cdata.allowance = allowance
  dict:set(key, ffi_str(rec_cdata, rec_size))

  return delay, floor(allowance)
end

return _M
