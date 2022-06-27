--!/usr/bin/lua


local cfg = require "config"
local cjson = require "cjson"
local ipmatcher = require "resty.ipmatcher"
local rate = require "rate"

local var = ngx.var
local req = ngx.req
local find = ngx.re.find
local clock = os.clock
local concat = table.concat
local format = string.format
local setmetatable = setmetatable


_M = {
  _VERSION = '0.01'
}

-- mt = {
  -- __index = mt
-- }
--
-- function _M.new()
  -- local self = {}
  -- return setmetatable(self, mt)
-- end

-- 加载配置跟规则
function _M.load(self, filepath)
  local count, err = cfg:load(filepath)
  if err then
    return nil, err
  end

  self.args = cfg:get_rule('args.rule')
  self.post = cfg:get_rule('post.rule')
  self.url = cfg:get_rule('url.rule')
  self.cookie = cfg:get_rule('cookie.rule')
  self.black_ip = cfg:get_rule('blackip.rule')
  self.white_ip = cfg:get_rule('whiteip.rule')
  self.white_url = cfg:get_rule('whiteurl.rule')
  self.user_agent = cfg:get_rule('useragent.rule')
  self.is_loaded = true

  -- ip 匹配
  self.black_ip_matcher = ipmatcher.new(self.black_ip)
  self.white_ip_matcher = ipmatcher.new(self.white_ip)

  -- cc 限制
  self.rate = rate.new(cfg.cc_store_key, cfg.cc_rate, cfg.cc_duration)
  return true
end


-- 匹配规则
local function match(rules, str)
  for _, rule in ipairs(rules) do
    if rule and find(str, rule, 'joi') then
      return true, rule
    end
  end
end

function _M.check_white_ip(self, ip)
  if not cfg.check_white_ip then
    return
  end

  return self.white_ip_matcher:match(ip)
end

function _M.check_black_ip(self, ip)
  if not cfg.check_black_ip then
    return
  end

  return self.black_ip_matcher:match(ip)
end

function _M.check_white_url(self, uri)
  if not cfg.check_white_url then
    return
  end

  return match(self.white_url, uri)
end

function _M.check_cookie_attach(self, cookie)
  if not cfg.check_cookie then
    return
  end

  return match(self.cookie, cookie)
end

function _M.check_user_agent_attach(self, user_agent)
  if not cfg.check_user_agent then
    return
  end

  return match(self.user_agent, user_agent)
end

function _M.check_url_attach(self, uri)
  if not cfg.check_url then
    return
  end

  return match(self.url, uri)
end

function _M.check_url_args_attach(self)
  if not cfg.check_url_args then
    return
  end

  local args = req.get_uri_args(0)
  for key, val in pairs(args) do
    local value
    if type(val) == 'table' then
      value = concat(val, ',')
    else
      value = val
    end

    if value and type(value) == "string" then
      local matched, rule = match(self.args, value)
      if matched then
        return matched, rule
      end
    end

  end
end

function _M.check_post_args_attach(self)
  if not cfg.check_post then
    return
  end

  local method = req.get_method()
  if method ~= "POST" and method ~= "PUT" and method ~= "UPDATE" then
    return
  end

  req.read_body()
  local args = req.get_post_args(0)
  for key, val in pairs(args) do
    local value
    if type(val) == 'table' then
      value = concat(val, ',')
    else
      value = val
    end

    if value and type(value) == "string" then
      local matched, rule = match(self.args, value)
      if matched then
        return matched, rule
      end
    end
  end
end

function _M.check_cc_attach(self, key)
  if not cfg.check_cc then
    return
  end

  local delay = self.rate:limit(key)
  return delay > 0
end

-- 检测规则
function _M.check(self)
  if not self.is_loaded then
    return false, nil, "", "please waf:load() config first"
  end

  -- 如果不启动防火墙, 直接返回
  if not cfg.enable then
    return
  end

  local client_ip = var.remote_addr
  local key = var.binary_remote_addr
  local user_agent = var.http_user_agent
  local uri = var.uri
  local cookie = var.http_cookie

  -- 如果是白名单ip，不检测
  if self:check_white_ip(client_ip) then
    return false, nil, 'white_ip'
  end

  -- 如果是黑名单
  if self:check_black_ip(client_ip) then
    return true, nil, 'black_ip'
  end

  -- 如果是cc 攻击
  if self:check_cc_attach(key) then
    return true, nil, 'cc_attach'
  end

  -- 如果是白名单地址, 跳过检测
  if self:check_white_url(uri) then
    return false, nil, 'white_url'
  end

  -- 如果是user agent攻击
  local ok, rule = self:check_user_agent_attach(user_agent)
  if ok then
    return ok, rule, 'user_agent_attach'
  end

  -- 如果是cookie攻击
  ok, rule = self:check_cookie_attach(cookie)
  if ok then
    return ok, rule, 'cookie_attach'
  end

  -- 如果是url攻击
  ok, rule = self:check_url_attach(uri)
  if ok then
    return ok, rule, 'url_attach'
  end

  -- 如果是请求参数攻击
  ok, rule = self:check_url_args_attach()
  if ok then
    return ok, rule, 'url_args_attach'
  end

  -- 如果是post参数攻击
  -- TODO: multiport form json body 等
  ok, rule = self:check_post_args_attach()
  if ok then
    return ok, rule, 'post_args_attach'
  end

end

function _M.check_and_output(self)
  local start = clock()
  local ok, rule, fn, err = self:check()
  if not ok then
    if err then
      ngx.log(ngx.ERR, "check error : " .. tostring(err))
    end
    return
  end

  local spent = (clock() - start) * 1000
  local user_agent = var.http_user_agent

  if cfg.redirect_uri then
    ngx.redirect(cfg.redirect_url, ngx.HTTP_MOVED_TEMPORARILY)
  else
    ngx.status = ngx.HTTP_FORBIDDEN

    local is_debug = cfg.content == "json" or cfg.content == "debug"
    if cfg.content and (is_debug or cfg.content:sub(1, 1) == '{') then
      ngx.header['Content-Type'] = 'application/json; charset=utf8'
    else
      ngx.header['Content-Type'] = 'text/html; charset=utf8'
    end

    if is_debug then
      local data = {
        remote_addr = var.remote_addr,
        type = fn,
        rule = rule,
        spent = spent,
        user_agent = user_agent,
      }
      ngx.say(cjson.encode(data))
    else
      ngx.say(cfg.content)
    end
  end

  ngx.eof()
  local line = format('%s %s %s spent %0.2fms', user_agent, tostring(rule), fn, spent)
  ngx.log(ngx.ERR, line)
end

return _M
