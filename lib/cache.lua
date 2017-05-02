
local cjson = require "cjson.safe"

local store = ngx.shared.luameter

local _M = {
	_VERSION = "0.0.1"

}

_M.set = function(key,value)
	
	local value = cjson.encode(value)
	store:set(key,value)

end


_M.get = function(key)

	local value ,err = store:get(key)
	if not value then
		return nil,err
	end

	local data = cjson.decode(value)
	return data
end


_M.remove = function(key)
	store:del(key)
end

return _M
