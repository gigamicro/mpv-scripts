local function paste(mode)
	local clip = mp.command_native{
		name = 'subprocess',
		capture_stdout = true,
		playback_only = false,
		args = {'xclip', '-sel','c', '-o'}
	}.stdout..'\n'
	for f in clip:gmatch('([^\n]*/[^\n]+)\n') do
		mp.commandv('loadfile', f, mode)
	end
end
mp.add_key_binding('ctrl+v', 'paste',    function()paste'append-play'end)
mp.add_key_binding('ctrl+V', 'altpaste', function()paste'insert-next-play'end)
local function getpl()
	local pl = mp.get_property_native("playlist")

	local newlines = 0
	for i,v in ipairs(pl) do
		local nl = 0
		pl[i], nl = v.filename:gsub('\n','\\\n')
		newlines = newlines + nl
	end
	if newlines > 0 then mp.msg.error(newlines..' newlines in filenames!') end
	return table.concat(pl,'\n')
end
mp.add_key_binding('ctrl+C', 'altcopy', function()
	local ret = mp.command_native{
		name = 'subprocess',
		playback_only = false,
		detach = true,
		args = {'xclip', '-sel','c', '-i'},
		stdin_data = getpl(),
	}
	if ret.status ~=0 then
		mp.msg.warn('process ended '..ret.error_string..' with status '..ret.status)
	end
end)
mp.add_key_binding('ctrl+D', 'altdrag', function()
	local ret = mp.command_native{
		name = 'subprocess',
		playback_only = false,
		detach = true,
		args = {
			'xargs', [[-d\n]], '-n100', '-P3',
			'dragon-drop', '-x', mp.get_property_native('playlist-count',0) > 32 and '-A' or '-a'
		},
		stdin_data = getpl(),
	}
	if ret.status ~=0 then
		mp.msg.warn('process ended '..ret.error_string..' with status '..ret.status)
	end
end)
