local function handle(vname,v)
	-- !! interrupt if not remote
	local function get(prop, def)
		if prop==vname then return v or def end
		return mp.get_property_native(prop,def)
	end
	local filesize = get('cache-speed',0) *125 *math.ceil(get('duration',0)/get('speed',1)) -- kbps, B/s, B
	local portion = 40/125 -- portion of bytes to dedicate audioward
	-- 40= ########################################-------------------------------------------------------------------------------------
	local format = 'ba*[filesize_approx<='..(filesize*portion)..']+bv*[filesize_approx<='..(filesize*(1-portion))..']/b[filesize_approx<='..filesize..']'
	format=format:gsub('%[[a-z_]+[<=>?]+0]','')
	if get('ytdl-format',format)~=format then mp.msg.debug('format=',format) end
	mp.set_property_native('ytdl-format',format)
end
mp.observe_property('cache-speed', 'native',handle)
mp.observe_property('speed', 'native',handle)
mp.observe_property('duration', 'native',handle)
