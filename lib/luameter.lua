
local cjson 	= require "cjson.safe"
local cache 	= require "luameter.lib.cache"
local utils 	= require "luameter.lib.utils"
local config 	= require "luameter.lib.config"

local errlog = utils.errlog
local info   = utils.info

local _M = {
	_VERSION = "0.0.1"
}

local luameter_key = "luameter"
local start_time = ngx.time()
local cache_seconds = config.cache_seconds


local floor = function(num)
	num = math.floor(num * 1000) 
	return num / 1000
end

local create_luameter = function()

	local luameter = {
		zones = {},
		upstreams = {},
	}
	return luameter

end

local create_zone= function()
	local zone = {

		lasts = {},

		responses = {
			['1xx'] = 0,
			['2xx'] = 0,
			['3xx'] = 0,
			['4xx'] = 0,
			['5xx'] = 0,
			total = 0,
		}
	}

	return zone
end

local creat_last_metric = function()
	local metric = {
			['1xx'] = 0,
			['2xx'] = 0,
			['3xx'] = 0,
			['4xx'] = 0,
			['5xx'] = 0,
			total = 0,
			body_bytes_sent = 0,
			request_time = 0,
			request_length = 0
	}

	return metric
end

-- get elapsed time (max is cache_seconds)
local cal_duration = function()
	local cached = cache_seconds
	local elapsed = ngx.time() - start_time

	if elapsed < cached then 
		if elapsed < 1 then
			return 1
		end

		return elapsed
	end

	return cached
end

local cal_sumlasts = function(lasts,key)
	local now = ngx.time()
	local total = 0
	local count = 0

	for time,last in pairs(lasts) do
		if tonumber(time) ~= now then
			total = total + last[key]
			count = count + 1
		end
	end

	return total,count
end


local update_lasts_metirc = function(lasts ,now)
	local now = tonumber(now or ngx.time())
	for timestamp,metric in pairs(lasts) do
		local past = now - tonumber(timestamp)
		if past > cache_seconds then
			lasts[timestamp] = nil
		end
	end
end


local update_zone = function(zone,http_merit)

	local status_key = tostring(http_merit.status):sub(1,1) .. 'xx'

	local responses = zone.responses
	responses.total = responses.total + 1
	responses[status_key] = responses[status_key] + 1

	local now = tostring(ngx.time())
	local lasts = zone.lasts

	if not lasts[now] then
		update_lasts_metirc(lasts,now)
		lasts[now] = creat_last_metric()
	end

	local last = lasts[now]

	last.total = last.total + 1
	last[status_key] = last[status_key] + 1
	last.body_bytes_sent = last.body_bytes_sent + http_merit.body_bytes_sent
	last.request_length = last.request_length + http_merit.request_length
	last.request_time = last.request_time + http_merit.request_time

end

local print_status = function(status)

	local output 
	local mime
	local query = ngx.req.get_uri_args()

	if 'clear' == query.method then
		cache.remove(luameter_key)
		return ngx.say('clean success')
	end

	local format = query.format 

	--TODO support for path query
	--local path = query.path
	
	if not format or format == "json"then
		mime = 'text/application'
		output = cjson.encode(status)
	elseif format == "plain" then
		mime = 'text/plain'
		output = tostring(status)
	else
		--TODO default is html that can be read by human
		mime = 'text/html'
		output = 'coming soon'
	end

	ngx.header['Content-Type'] = mime 
	return ngx.say(output)
end



_M.log = function(key)

	if not key then
		errlog("need to specify log key")
		return
	end

	local Luameter = cache.get(luameter_key)
	if not Luameter then
		Luameter = create_luameter()
	end

	local http_merit = {
		status 				= ngx.var.status,
		body_bytes_sent 	= ngx.var.body_bytes_sent,
		request_length 		= ngx.var.request_length,
		request_time 		= ngx.var.request_time,
	}

	--local upstream_metri = {
	--	upstream_addr 				= ngx.var.upstream_addr,
	--	upstream_response_time 		= ngx.var.upstream_response_time,
	--	upstream_status 			= ngx.var.upstream_status,
	--	upstream_response_length 	= ngx.var.upstream_response_length,
	--}
	-- TODO upstream statistics

	if not Luameter.zones[key] then
		Luameter.zones[key] = create_zone()
	end
	local zone = Luameter.zones[key]

	update_zone(zone,http_merit)

	cache.set(luameter_key,Luameter)
end

_M.get_status = function()
	
	local status = {
		nginx_version = ngx.var.nginx_version,
		nginx_ip = ngx.var.server_addr,
		timestamp = ngx.now() * 1000,
		pid = ngx.worker.pid(),
		cache_seconds = cache_seconds,
	}

	local data = cache.get(luameter_key) or {}
	local zones = {}

	for key,zone in pairs(data.zones) do
		update_lasts_metirc(zone.lasts)
		
		local ret = {}
		local duration = cal_duration()
		local total,count = cal_sumlasts(zone.lasts,"total")
		ret.total = total

		if duration == 0 or total == 0 then
			ret.request_per_second = 0
			ret.avg_response_time = 0
			ret.avg_body_bytes_sent = 0
			ret['2xx_percent'] = 0
		else
			ret.request_per_second =  floor(total / duration)
			ret.avg_response_time = floor(cal_sumlasts(zone.lasts,"request_time") / total)
			ret.avg_body_bytes_sent = floor(cal_sumlasts(zone.lasts,"body_bytes_sent") / total)
			ret['2xx_percent'] = floor(cal_sumlasts(zone.lasts,"2xx") / total)
		end

		zones[key] = ret
	end

	status.zones = zones

	return print_status(status)
end



return _M
