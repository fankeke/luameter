--
local _M = {
	_VERSION = "0.0.1"
}

local log_sign = "[==Luemeter==]"

_M.errlog = function(...)
	ngx.log(ngx.ERR,log_sign,' ',...)
end

_M.info = function(...)
	ngx.log(ngx.INFO,log_sign,' ',...)
end

return _M
