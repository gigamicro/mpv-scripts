local resolution = 1/32
local seeks=0
mp.register_event('seek',function(ev)
	local target=mp.get_property_native('time-pos/full')
	mp.add_timeout(resolution*2, function()
		if not target then mp.msg.err 'nil target' return end
		local newpos=mp.get_property_native('time-pos/full')
		if target==newpos or math.floor(target/resolution+0.5)==math.floor(newpos/resolution+0.5) then
			if not target==newpos then mp.msg.err('diff',target-newpos) end
			mp.msg.info 'seek(0)'
			mp.commandv('seek',0)
			seeks=seeks+1
			if seeks*resolution > 1 then -- half second of troubleshooting
				if mp.get_property_native('play-direction') == 'backward' then
					mp.commandv('seek',-resolution)
					target=target-resolution
				else
					mp.commandv('seek', resolution)
					target=target+resolution
				end
			end
		else
			target=nil
			seeks=0
		end
	end)
end)
