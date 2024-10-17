local netspeed = 14660000
local function handle(vname,v)
	local function get(prop, def)
		if prop==vname then return v or def end
		return mp.get_property_native(prop,def)
	end
	do
		-- interrupt if not remote
		local path = get('path','')
		if path:match'^/' or path:match'^file:///' then
			return
		end
	end

	local speedtick = get('cache-speed', -1) -- bytes in last second
	if speedtick > 0 then
		local oldspeed=netspeed
		netspeed = netspeed/2 + speedtick/2
		mp.msg.info('Netspeed estimate is now',netspeed,'(tick =',speedtick,') (from =',oldspeed,')')
	end

	local filesize = netspeed * get('duration',0)/get('speed',1) -- B/s * s = B
	local aportion = 40/125
	local vportion = 85/125
	-- 40= ########################################-------------------------------------------------------------------------------------
	local format = 'ba*[filesize_approx<='..math.floor(filesize*aportion)..']+bv*[filesize_approx<='..math.floor(filesize*vportion)..']/b[filesize_approx<='..math.floor(filesize)..']'
	format=format:gsub('%[[a-z_]+[<=>?]+0]','')
	if get('ytdl-format',format)~=format then mp.msg.debug('format=',format) end
	mp.set_property_native('ytdl-format',format)
end
mp.observe_property('cache-speed', 'native',handle)
mp.observe_property('speed', 'native',handle)
mp.observe_property('duration', 'native',handle)
