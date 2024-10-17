-- local yet = false
--local event = function(s)return s,function(v)mp.msg.info(s,v)end end
-- mp.register_event(event'audio-reconfig')
-- mp.register_event(event'client-message')
-- mp.register_event(event'command-reply')
--mp.register_event(event'end-file')
-- mp.register_event(event'file-loaded')
-- mp.register_event(event'get-property-reply')
-- mp.register_event(event'log-message')
-- mp.register_event(event'playback-restart')
-- mp.register_event(event'property-change')
--mp.register_event(event'seek')
-- mp.register_event(event'set-property-reply')
-- mp.register_event(event'shutdown')
--mp.register_event(event'start-file')
-- mp.register_event(event'video-reconfig')

-- before EOF, reverse play direction
-- maybe only when looping
local inprogress = false
return
mp.register_event('seek',function(ev)
	if not mp.get_property_native('loop-file') then return end
	local playdir = mp.get_property_native('play-direction')
	local dur = mp.get_property_native('duration')
	local pos = mp.get_property_native('time-pos/full')
	mp.msg.info(
		inprogress,
		pos,
		dur,
		playdir,
		mp.get_property_native('loop-file'),
		mp.get_property_native('seeking'),
		nil)
	if (playdir=='forward' and 0 or dur)==pos then -- just seeked to start of playback
		if inprogress then
			mp.msg.info 'unsetting inprogress'
			inprogress=false
			return
		end
		mp.msg.info 'setting inprogress'
		inprogress=true
		mp.set_property_native('play-direction',playdir=='forward' and 'backward' or 'forward')
		if playdir=='forward' then mp.commandv('seek',dur-0.0625) inprogress=false end -- when reversing, reseek
		return
	else mp.msg.info 'fallthrough'
	end
end)
