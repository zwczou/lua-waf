# Lua WAF


### 使用说明

```nginx
lua_shared_dict cc_limited 10m;
lua_package_path "/path/to/lua-waf/lib/waf/?.lua;;";
init_by_lua_file /path/to/lua-waf/init.lua;
access_by_lua_file /path/to/lua-waf/access.lua;
```
