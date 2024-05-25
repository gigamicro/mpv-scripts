mp.observe_property('speed', 'native',function(_,speed)
	-- bestvideo[height<=?720][fps<=?30][vcodec!=?vp9]+bestaudio/best
	local fps = '[fps<=?'..(mp.get_property_native('display-fps',60)/speed)..']'
	local format, count = mp.get_property_native('ytdl-format',''):gsub('(%[fps<[=?]+)%d+]',fps)
	if count == 0 then
		format=format..fps
	elseif count > 1 then
		format=format:gsub('(%[fps<[=?]+)[0-9.]+]','')..fps
	end
	mp.msg.info(count, format)
	mp.set_property_native('ytdl-format',format)
end)
-- also want to limit quality by bandwidth
-- audio sample rate?
