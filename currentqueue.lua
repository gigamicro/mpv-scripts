local dir = (os.getenv('APPDATA') or os.getenv('HOME')..'/.config')..'/mpv/q'
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
		math.randomseed(os.time())
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
				close()
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

local playlistpos, playlistposplaylistpath = nil, nil
mp.add_key_binding(':', 'firstqueue', function()
	if not endhandle() then close() end -- close, delete if normally would be deleted
	mp.commandv'stop'
	mp.commandv'playlist-clear'
	local first_queue
	do
		local fp = io.popen('ls -A "'..dir..'"')
		if not fp:read(0) then mp.msg.error 'No queues'; return end
		first_queue = dir..'/'..fp:read'l'
		fp:close()
	end
	local fp = io.open(first_queue, 'r')
	if not fp then mp.msg.error('no file pointer in firstqueue bind!') return end
	local first, pos, playlistpath = true, 0, ''
	for l in fp:lines() do
		local comment
		l,comment=l:gsub(' *$',''):gsub('^#','')
		if l:match'^#' then
			l=l:gsub('^#','')
			pos=pos-1
			playlistpath = l
		end
		if l~='' and (playlistpath=='' or playlistpath==l) then
			local _ = mp.commandv('loadfile', l, 'append-play')
			 or mp.commandv('loadfile', l:gsub([[\n]],'\n'), 'append-play')
			 or mp.msg.error('could not load file "'..l..'"')
		end
		if first and comment==0 then
			first=false
			if mp.get_property_native('playlist-count', 0) > pos then
				mp.set_property_native('playlist-pos', pos+1)
				playlistpos=nil
				playlistpospath=nil
			else
				playlistpos=pos
				playlistpospath=l
			end
		end
		pos=pos+1
	end
	mp.commandv('show-text','q loaded')
	close()
	os.remove(first_queue) -- XXX no conditions
end)

mp.register_event('end-file',function(ev)
	if not playlistpos then return end
	if ev.reason~='redirect' then playlistpos=nil return end
	if mp.get_property_native('playlist-count', 0) <= playlistpos then return end
	if mp.get_property_native('playlist/'..playlistpos..'/filename') ~= playlistpospath then
		mp.msg.info('filename for id',
			playlistpos,
			mp.get_property_native('playlist/'..playlistpos..'/filename'),
			'doesn\'t match',
			playlistpospath)
		playlistpos = nil
		for i, v in ipairs(mp.get_property_native('playlist',{})) do
			if v.filename == playlistpospath then
				playlistpos = i-1
				break
			end
		end
		if not playlistpos then return end
		mp.msg.info('found it at index',playlistpos)
	end
	mp.set_property_native('playlist-pos', playlistpos)
	playlistpos=nil
	playlistpospath=nil
end)
