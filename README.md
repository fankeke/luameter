Luameter
========


Description
===========

Luameter is a In-Time monitor for OpenResty or ngx_lua.etc. 


Configuration
============

In nginx.conf 

``` 

lua_shared_dict   luameter  10m;
log_by_lua_file   "/path/to/luameter/log.lua";

server {
	listen 8888 default_server;

	location /status {
		content_by_lua_file "/path/to/luameter/src/status.lua";
	}
```

Interface
============




