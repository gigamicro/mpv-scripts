-- do return end
local function handle(vname,v)
	-- bestvideo[height<=?720][fps<=?30][vcodec!=?vp9]+bestaudio/best
	local function get(prop, def)
		if prop==vname then return v or def end
		return mp.get_property_native(prop,def)
	end
	--[=[
	local speed = get('speed',1)
	local fps = '[fps<=?'..math.ceil(get('display-fps',60)/speed)..']'
	local osd_dims = get('osd-dimensions')
	local width, height = '[width<=?'..osd_dims.w..']','[height<=?'..osd_dims.h..']'
	local vcodec = '[vcodec!=?vp9]'
	local samplerate = '[asr<=?'..(48000/speed)..']'
	local cachespeed = get('cache-speed',0)*(1000--[[kbps to bps]])/speed
	-- local bitrate = '[tbr<=?'..math.floor(cachespeed*(0.5--[[a/v even bitrate]]))..']' -- abr, vbr
	-- local avbitrate = '[tbr<=?'..math.floor(cachespeed)..']'
	local bitrate = '[filesize_approx<=?'..math.ceil(get('duration',0) * (cachespeed/8) /2)..']'
	local avbitrate = '[filesize_approx<=?'..math.ceil(get('duration',0) * (cachespeed/8))..']'

	local format = (
	'bv'..fps..width..height..vcodec..bitrate
	..'+'..
	'ba'..samplerate..bitrate
	..'/b'..fps..width..height..vcodec..samplerate..avbitrate
	)--:gsub('%[[a-z_]+[<=>?]+0]','')
	-- no video? muted?
	--local format = 'b[tbr<='..(get('cache-speed',1000000)*1000--[[kbps to bps]]/8--[[bytes/s]])..']'
	--]=]
	local filesize = get('cache-speed',0)*125*get('duration',0) -- kbps, B/s, B
	local portion = 40/125 -- portion of bytes to dedicate audioward
	-- 40= ########################################-------------------------------------------------------------------------------------
	local format = 'ba*[filesize_approx<='..(filesize*portion)..']+bv*[filesize_approx<='..(filesize*(1-portion))..']/b[filesize_approx<='..filesize..']'
	format=format:gsub('%[[a-z_]+[<=>?]+0]','')
	if get('ytdl-format',format)~=format then mp.msg.info(format) end
	mp.set_property_native('ytdl-format',format)
end
mp.observe_property('cache-speed', 'native',handle)
mp.observe_property('speed', 'native',handle)
-- mp.observe_property('display-fps', 'native',handle)
-- mp.observe_property('osd-dimensions', 'native',handle)
