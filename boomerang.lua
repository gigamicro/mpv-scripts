local opts = {enabled=true}
-- TODO?: add mode for 1x forward, 1x reverse, then on to next file
require'mp.options'.read_options(opts)
local inprogress = false
mp.register_event('seek',function(ev)
	if not opts.enabled then return end
	if not mp.get_property_native('loop-file') then return end
	local playdir = mp.get_property_native('play-direction')
	local dur = mp.get_property_native('duration')
	local pos = mp.get_property_native('time-pos/full')
	if (playdir=='forward' and 0 or dur)==pos then -- just seeked to start of playback
		if inprogress then inprogress=false return end
		inprogress=true
		mp.set_property_native('play-direction',playdir=='forward' and 'backward' or 'forward')
		if playdir=='forward' then mp.commandv('seek',dur-0.0625) inprogress=false end -- when reversing, reseek
		return
	end
end)
