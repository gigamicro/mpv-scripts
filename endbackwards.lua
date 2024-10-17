local resolution = 1/32
local seeks=0
mp.register_event('seek',function(ev)
	if mp.get_property_native('play-direction') ~= 'backward' then return end
	local target=mp.get_property_native('time-pos/full')
	if mp.get_property_native('duration') > target+resolution then return end
	mp.msg.debug 'watching'
	mp.add_timeout(resolution*2, function()
		if not target then mp.msg.err 'nil target' return end
		local newpos=mp.get_property_native('time-pos/full')
		mp.msg.debug('backtest at',newpos,'vs',target)
		if target==newpos or math.floor(target/resolution)==math.floor(newpos/resolution) then
			if not target==newpos then mp.msg.info('diff',target-newpos) end
			mp.msg.info'+seek'
			mp.commandv('seek',0)
			seeks=seeks+1
			if seeks*resolution > 1 then
				mp.commandv('seek',-resolution)
				target=target-resolution
			end
		else
			target=nil
			seeks=0
		end
	end)
end)
