local opts = {enabled=true}
require'mp.options'.read_options(opts)
local lastloop
mp.register_event('seek',function(ev)
	if not opts.enabled then return end
	local looptype =
	mp.get_property_native('remaining-file-loops') ~= 0
	 or 
	mp.get_property_native('remaining-ab-loops') ~= 0
	 and mp.get_property_native('ab-loop-a','no')~='no'
	 and mp.get_property_native('ab-loop-b','no')~='no'

	looptype, lastloop = looptype or lastloop, looptype
	if not looptype then return end

	local a = mp.get_property_native('ab-loop-a')
	local b = mp.get_property_native('ab-loop-b')
	if b < a then a,b=b,a end
	local playdir = mp.get_property_native('play-direction')
	local pos = mp.get_property_native('time-pos/full')
	if a==pos and playdir=='forward' then
		mp.set_property_native('play-direction','backward')
		mp.commandv('seek',b-1/64,'absolute')
		return
	end
	if b==pos and playdir=='backward' then
		mp.set_property_native('play-direction','forward')
		mp.commandv('seek',a+1/64,'absolute')
		return
	end
	local d = mp.get_property_native('duration')
	if 0==pos and playdir=='forward' then
		mp.set_property_native('play-direction','backward')
		mp.commandv('seek',d-1/12,'absolute')
		return
	end
	if d==pos and playdir=='backward' then
		mp.set_property_native('play-direction','forward')
		mp.commandv('seek',0+1/64,'absolute')
		return
	end
end)
