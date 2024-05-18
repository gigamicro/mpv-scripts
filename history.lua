-- https://www.reddit.com/r/linuxquestions/comments/3t6s7k/comment/cylbpf7/
local HISTFILE = (os.getenv('APPDATA') or os.getenv('HOME')..'/.config')..'/mpv/history.log';

mp.register_event('file-loaded', function()
    local title = mp.get_property('media-title');
    title = (title == mp.get_property('filename') and '' or (' (%s)'):format(title:gsub(' %(','（')));

    local fp = io.open(HISTFILE, 'a+');
    fp:write(os.date('[%Y-%m-%d %X] ')..mp.get_property('path')..title..'\n');
    fp:close();
end)
--[[
-- mp.register_event('idle', function()
mp.add_key_binding(':', 'historyplay', function()
    local fp = io.open(HISTFILE, 'r')
    if not fp then return end
    fp:seek('end', -1024) -->pos (num)
    fp:read('*l') -->partial line (str)
    local lines = {}
    -- io.lines(HISTFILE)
    for l in fp:lines() do
        lines[#lines+1] = l:gsub('^%[%d+%-%d%d%-%d%d %d%d%:%d%d%:%d%d%] *',''):gsub(' +%(.-%)$','')
    end
    fp:close()

    local n = 0
    for i = #lines, 1, -1 do
        if lines[i] ~= '' then
            n = n+1
            mp.commandv('loadfile', lines[i], n==1 and 'append-play' or 'append');
            -- if n >= 4 then break end
        end
    end
end)
--]]
