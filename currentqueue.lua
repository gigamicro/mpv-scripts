local dir = (os.getenv('APPDATA') or os.getenv('HOME')..'/.config')..'/mpv/q'
math.randomseed(os.time())
local file, fp, lastpos, lastlen
local function close()
	if not fp then return end
	fp:close()
	fp = nil
	lastpos=-2
	lastlen=-1
end
local function handle(_,pl)
	local len = mp.get_property_native('playlist-count',0)
	if (lastlen or 0) > len+2 then
		close()
	else
		lastlen=len
	end
	if not fp then
		file = dir..'/q'..os.date('%Y-%m-%dT%H:%M:%S')..('.%04d'):format(math.random(0,10^4))..'.m3u'
		fp = io.open(file, 'w')
		if not fp then
			os.execute('mkdir "'..dir..'"')
			fp = io.open(file, 'w')
		end
	end
	do -- remove extra data, new line handling, comment played, 
		local newlines = 0
		local nonlocal = false
		local lastplaylist = nil
		local pos = mp.get_property_native('playlist-pos-1',1)
		for i,v in ipairs(pl) do
			if nonlocal then -- do nothing
			elseif not (v.filename:match('^/') or v.filename:match('^file:///')) then
				nonlocal = true -- there's been a remote file
			elseif i>100 then -- there's more than a hundred local files in a row at the start
				-- close()
				os.remove(file)
				return
			end

			local playlist = v['playlist-path']
			local plprefix = ''
			if playlist ~= lastplaylist then
				plprefix = '##'..(playlist or '')..'\n'
				lastplaylist = playlist
			end

			local nl = 0
			pl[i], nl = v.filename:gsub('\n',[[\n]])
			newlines = newlines + nl

			if i<pos then pl[i]='#'..pl[i] end
			pl[i] = plprefix..pl[i]
		end
		if newlines > 0 then mp.msg.warn(newlines,' newlines in filenames!') end
	end
	pl[#pl]=pl[#pl] and pl[#pl]:gsub('%s*$',(' '):rep(#pl))
	fp:seek('set',0)
	fp:write(table.concat(pl,'\n'),'\n');
end
local function endhandle()
	-- mp.msg.info(lastpos, '?=', mp.get_property_native('playlist-count',0))
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

local playlistpos, playlistpospath = nil, nil
mp.add_key_binding(':', 'firstqueue', function()
	if not endhandle() then close() end -- close, delete if normally would be deleted
	mp.commandv'stop'
	mp.commandv'playlist-clear'
	local readingq
	do -- get first queue
		local fp = io.popen('ls -A "'..dir..'"')
		if not fp:read(0) then mp.msg.error 'No queues'; return end
		readingq = dir..'/'..fp:read'l'
		fp:close()
	end
	local first, playlistpath = true, ''
	for l in io.lines(readingq) do mp.msg.info('line is "',l,'"')
		local past,isplaylist
		l,past=l:gsub(' *$',''):gsub('^#','')
		l,isplaylist=l:gsub('^#','')
		if isplaylist>0 then
			playlistpath = l
			if first then
				playlistpos=0
			end
		end
		if l~='' and (isplaylist>0 or playlistpath=='') then
			local status = mp.commandv('loadfile', l, 'append-play')
			 or mp.commandv('loadfile', l:gsub([[\n]],'\n'), 'append-play')
			if not status then
				mp.msg.error('could not load file "'..l..'"')
				readingq=nil
			end
		end
		if first then
			if past==0 then
				mp.set_property_native('playlist-pos', mp.get_property_native('playlist-count', 1)-1)
				first=false
				if playlistpath=='' then
					playlistpos=nil
					playlistpospath=nil
				else
					playlistpospath=l
				end
			else
				playlistpos=playlistpos and playlistpos+1
			end
		end
	end
	mp.commandv('show-text','q loaded')
	close()
	os.remove(readingq) -- XXX no conditions
end)

mp.register_event('end-file',function(ev)
	if not playlistpos then return end
	if ev.reason~='redirect' then playlistpos=nil return end
	if ev.playlist_insert_num_entries < playlistpos then return end
	local playlistposabs=playlistpos+ev.playlist_entry_id-2
	if mp.get_property_native('playlist-count', 0) <= playlistposabs then return end
	playlistpos=nil
	if mp.get_property_native('playlist/'..playlistposabs..'/filename') ~= playlistpospath then
		mp.commandv('show-text','q filename mismatch')
		mp.msg.info('filename for id',
			playlistposabs,',',
			mp.get_property_native('playlist/'..playlistposabs..'/filename'),
			'doesn\'t match expected',
			playlistpospath)
		playlistposabs = nil
		for i, v in ipairs{},(mp.get_property_native('playlist',{})), ev.playlist_insert_id-1 do
			if v.filename == playlistpospath then
				playlistposabs = i-1
				break
			end
		end
		if not playlistposabs then return end
		mp.msg.info('found it at index',playlistposabs)
	end
	mp.set_property_native('playlist-pos', playlistposabs)
	playlistpospath=nil
end)
