# Lua WAF


### 使用说明

1. 首先修改 `init.lua` 里面的`waf_path`为你自己的绝对陆军
2. 然后将下面的nginx配置放在`http{}`里，并且修改路径

```nginx
lua_shared_dict cc_limited 10m;
lua_package_path "/path/to/lua-waf/lib/waf/?.lua;;";
init_by_lua_file /path/to/lua-waf/init.lua;
access_by_lua_file /path/to/lua-waf/access.lua;
```

### 感谢

* 感谢`unixhot/waf`跟`loveshell/ngx_lua_waf`
* 其中`loveshell/ngx_lua_waf`已经早就不维护了
* 而`unixhot/waf`每次请求都需要从新加载配置
