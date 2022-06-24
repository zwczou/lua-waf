# Lua WAF


### 使用说明

1. 首先修改 `init.lua` 里面的`waf_path`为你自己的绝对路径
2. 然后将下面的nginx配置放在`http{}`里，并且修改路径

```nginx
lua_shared_dict cc_limited 10m;
lua_package_path "/path/to/lua-waf/lib/waf/?.lua;;";
init_by_lua_file /path/to/lua-waf/init.lua;
access_by_lua_file /path/to/lua-waf/access.lua;
```

### 配置文件

目前waf配置文件并没有使用JSON或者lua文件, 位置在`conf/waf.conf`
使用`true`或者`on`都表示打开，`false`或者`off`代表关闭
由于目前简单的替换字符串的`"'`，所以不能直接在`content`配置写`JSON`内容
需要在`content` 配置的文件里面写入`JSON`返回内容

```nginx
enable = true # 启动waf

check_white_ip = true # 检测白名单

check_black_ip = true # 检测黑名单

check_url = true # 检测请求路径

check_url_args = true # 检测请求参数

check_user_agent = true # 检测请求代理

check_cookie = false # 检测cookie

check_post = false # 检测post请求

check_cc = true # 检测CC攻击

cc_rate = 100 # 请求次数

cc_duration = 60 # 检测时长

cc_store_key = "cc_limited" # 需要在配置里面设置 lua_shared_dict cc_limited 20m;

redirect_url = # 重定向

#content = deny.html # 输出内容, 如果是文件路径，显示文件内容, 支持文件里面包含html,json
content = debug # 显示debug信息
```

### 感谢

* 感谢`unixhot/waf`跟`loveshell/ngx_lua_waf`
* 其中`loveshell/ngx_lua_waf`已经早就不维护了
* 而`unixhot/waf`每次请求都需要从新加载配置
