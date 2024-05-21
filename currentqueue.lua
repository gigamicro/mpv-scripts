local dir = (os.getenv('APPDATA') or os.getenv('HOME')..'/.config')..'/mpv/q'
local file, fp, lastpos
local function close()
	if not fp then return end
	fp:close()
	fp = nil
	lastpos=-2
end
local function handle(_,pl)
	if not fp then
		file = dir..'/q'..os.date('%Y-%m-%dT%H:%M:%S')..'.m3u'
		fp = io.open(file, 'w')
		if not fp then
			os.execute('mkdir "'..dir..'"')
			fp = io.open(file, 'w')
		end
	end
	do -- remove extra data, new line handling, comment played
		local newlines = 0
		local pos = mp.get_property_native('playlist-pos-1',1)
		for i,v in ipairs(pl) do
			local nl = 0
			pl[i], nl = v.filename:gsub('\n',[[\n]])
			newlines = newlines + nl

			if i<pos then pl[i]='#'..pl[i] end
		end
		if newlines > 0 then mp.msg.warn(newlines..' newlines in filenames!') end
	end
	pl[#pl]=pl[#pl] and pl[#pl]:gsub('%s*$',(' '):rep(#pl))
	fp:seek('set',0)
	fp:write(table.concat(pl,'\n'),'\n');
end
local function endhandle()
	mp.msg.info(lastpos, '?=', mp.get_property_native('playlist-count',0))
	if lastpos == -1 or lastpos == mp.get_property_native('playlist-count',0) then
		mp.msg.info 'Cleaning playlist file!'
		close()
		os.remove(file)
		return true
	end
end
mp.observe_property("playlist", "native", handle)
mp.observe_property("playlist-pos-1", "native", function(_,pos)
	if pos==-1 then endhandle() end lastpos=pos
	handle('playlist',mp.get_property_native('playlist'))
end)
mp.register_event('shutdown', endhandle)

mp.add_key_binding(':', 'firstqueue', function()
	if not endhandle() then close() end
	mp.commandv'stop'
	local first_queue
	do
		local fp = io.popen('ls -A "'..dir..'"')
		if not fp:read(0) then mp.msg.error 'No queues'; return end
		first_queue = dir..'/'..fp:read'l'
		fp:close()
	end
	mp.msg.info('Playing from '..first_queue)
	local fp = io.open(first_queue, 'r')
	if not fp then mp.msg.error('no file pointer in firstqueue bind!') return end
	local first = 0
	for l in fp:lines() do
		local comment = 0
		l,comment=l:gsub('^#','')
		if first then
			first=first+1
			if comment==0 then
				mp.set_property_native('playlist-pos', first)
				first=nil
			end
		end
		local _ = mp.commandv('loadfile', l, 'append-play')
		 or mp.commandv('loadfile', l:gsub([[\n]],'\n'), 'append-play')
		 or mp.msg.error('could not load file "'..l..'"')
	end
	fp:close()
	os.remove(first_queue)
end)
