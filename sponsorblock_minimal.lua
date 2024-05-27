-- https://codeberg.org/jouni/mpv_sponsorblock_minimal/src/branch/master/sponsorblock_minimal.lua
-- sponsorblock_minimal.lua
--
-- This script skips sponsored segments of YouTube videos
-- using data from https://github.com/ajayyy/SponsorBlock

local mp = mp
local utils = require 'mp.utils'

local options = {
	server = "https://sponsor.ajay.app/api/skipSegments",

	-- Categories to fetch and skip
	categories = '["sponsor","interaction","preview","intermission"]',

	-- Set this to use n digits of sha256HashPrefix instead of videoID (4 recommended)
	hash = 0,

	toggle_key='b',
	enabled=true,
}
require 'mp.options'.read_options(options)

local ranges = nil

local function skip_ads(_, pos)
	if not pos then return end
	for _, range in pairs(ranges) do
		local endpos = range.segment[2]
		if range.segment[1] <= pos and endpos > pos then
			--this message may sometimes be wrong
			--it only seems to be a visual thing though
			mp.osd_message(("[sponsorblock] skipping %ds"):format(endpos-mp.get_property("time-pos")))
			--need to do the +0.01 otherwise mpv will start spamming skip sometimes
			--example: https://www.youtube.com/watch?v=4ypMJzeNooo
			mp.set_property("time-pos",endpos+0.01)
			return endpos
		end
	end
end

local function toggle()
	if options.enabled then
		mp.unobserve_property(skip_ads)
		mp.osd_message("[sponsorblock] off")
		options.enabled = false
	else
		mp.observe_property("time-pos", "native", skip_ads)
		mp.osd_message("[sponsorblock] on")
		options.enabled = true
	end
end
mp.add_key_binding(options.toggle_key,"toggle",toggle)

local function get_ytid(vars)
	local patterns = {
		                "ytdl://youtu%.be/([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])",
		  "ytdl://w?w?w?%.?youtube%.com/v/([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])",
		              "https?://youtu%.be/([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])",
		"https?://w?w?w?%.?youtube%.com/v/([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])",
		                   "/watch.*[?&]v=([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])",
		                          "/embed/([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])",
		                         "^ytdl://([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])$",
		                              " %[([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])%]%.",
		                                "-([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])%.",
		                                 "([%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_][%w-_])",
	}
	for _, pattern in ipairs(patterns) do
		for _, var in ipairs(vars) do
			local id = string.match(var, pattern)
			if id then return id end
		end
	end
end

local function file_loaded()
	if not options.enabled then return end

	local youtube_id = get_ytid{
		mp.get_property("filename", ""),
		mp.get_property("path", ""),
		string.match(mp.get_property("http-header-fields", ""), "Referer:([^,]+)") or "",
		mp.get_property("metadata/by-key/PURL", ""),
	}
	mp.msg.info(youtube_id)
	if not youtube_id or string.len(youtube_id) < 11 then return end
	if string.len(youtube_id) > 11 then mp.msg.info('ytid len',string.len(youtube_id),'; "'..youtube_id..'"') end
	youtube_id = string.sub(youtube_id, 1, 11)

	local curl_args = { "curl", "--location", "--silent", "--get", "--data-urlencode","categories="..options.categories }
	local url = options.server
	if tonumber(options.hash)>0 then
		local sha = mp.command_native{
			name = "subprocess",
			capture_stdout = true,
			args = {"sha256sum"},
			stdin_data = youtube_id
		}.stdout
		url = ("%s/%s"):format(url, string.sub(sha, 0, tonumber(options.hash)))
	else
		table.insert(curl_args, "--data-urlencode")
		table.insert(curl_args, "videoID="..youtube_id)
	end
	table.insert(curl_args, url)

	mp.msg.debug(table.concat(curl_args,' '))
	local sponsors = mp.command_native{
		name = "subprocess",
		capture_stdout = true,
		playback_only = false,
		args = curl_args
	}

	if sponsors.stdout then
		local json = utils.parse_json(sponsors.stdout)
		if type(json) == "table" then
			if tonumber(options.hash)>0 then
				ranges = nil
				for _, video in pairs(json) do
					if video.videoID == youtube_id then
						ranges = video.segments
						break
					end
				end
			else
				ranges = json
			end

			if ranges then
				options.enabled = true
				-- mp.add_key_binding(options.toggle_key,"sponsorblock",toggle)
				mp.observe_property("time-pos", "native", skip_ads)
			end
		else
			-- mp.msg.error('json not table')
		end
	end
end

local function end_file()
	if not options.enabled then return end
	mp.unobserve_property(skip_ads)
	ranges = nil
end

mp.register_event("file-loaded", file_loaded)
mp.register_event("end-file", end_file)
