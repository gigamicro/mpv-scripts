-- various audio visualization
-- original source: https://github.com/mfcc64/mpv-scripts

-- default settings
local opts = {
    --mode = 'force',
    name = 'av',
    fps = 48,
    -- width = 1920,
    height= 1080,
    ratio = 1,--16/6, -- 16/[4..12]
}
local cycle_key = "v"
-- /default settings

local mp = mp

if mp.get_property("lavfi-complex", "") ~= "" then
    return
end

require'mp.options'.read_options(opts)

-- cycling
local namelist = {
    "ao",
    "av",
    "showcqt",
    "avectorscope",
    -- "avectorscope-dots",
    "showwaves",
    -- "showwaves-dots",
    -- "showwaves-mid",
    "showwaves-high",
    -- "showwaves-low",
    -- "showspectrum",
    -- "showcqt-bar",
    -- 'invalid :)'
}
local namelist_r = {}
for k,v in pairs(namelist) do
    namelist_r[v] = k
end
local last_cycleby = 1
local function cycle(by)
    last_cycleby=by
    mp.msg.trace('Cycling by',by,'from',opts.name,'([',namelist_r[opts.name],'])')
    opts.name = namelist[((namelist_r[opts.name] or 0)+by-1)%#namelist+1]
    mp.msg.trace('Cycled to',opts.name)
    mp.osd_message(opts.name)
    return opts.name
end
-- /cycling

--add initialized name to list, replacing base if variant
if opts.name:find'-' then
    local basename = opts.name:gsub('-.+$','')
    namelist[namelist_r[basename]]=opts.name -- add new val
    namelist_r[opts.name]=namelist_r[basename] -- add new pointer
else
    local name = opts.name
    if not namelist_r[name] then
        namelist_r[name] = #namelist+1
        namelist[namelist_r[name]] = name
    end
end

local aid,vid

local function get_visualizer(name)
    -- https://ffmpeg.org/ffmpeg-filters.html

    local osd_dims = mp.get_property_native('osd-dimensions')
    local w, h =  osd_dims.w~=0 and osd_dims.w or opts.width,  osd_dims.h~=0 and osd_dims.h or opts.height
    if not w and not h then
        mp.msg.error("invalid size")
        return
    end
    w, h = w or h*opts.ratio, h or w/opts.ratio

    local fps = opts.fps
    if not fps or not w or not h then
        mp.msg.error("invalid quality")
        return
    end

    if false then
    elseif name == 'ao' then
        if mp.get_property_bool('force-window') then
            return get_visualizer(cycle(last_cycleby))
        else
            return "[aid"..aid.."] asetpts=PTS [ao]"
        end


    elseif name == "av" then
        for _, track in ipairs(mp.get_property_native("track-list")) do
            if vid then break end
            if track.type == "video" then
                vid = track.id
            end
        end
        if vid then
            return "[aid"..aid.."] asetpts=PTS [ao]; [vid"..vid.."] setpts=PTS [vo]"
        else
            return get_visualizer(cycle(last_cycleby))
        end


    elseif name == "showcqt" then
        return "[aid"..aid.."] asplit [ao]," ..
            "showcqt"..     "=" ..
                "fps"..     "="..fps..":" ..
                "size"..    "="..(math.floor(w/2)*2).."x"..(math.floor(h/2)*2)..":" ..
                "count"..   "="..math.ceil(h /12 /fps)..":" .. -- 1/rate downward, min 1
                "csp"..     "=bt709:" ..
                "bar_g"..   "=2:" ..
                "sono_g"..  "=4:" ..
                "bar_v"..   "=sono_v*9/17:" ..
                "sono_v"..  "=17*0.95*(f*6e-3)/sqrt(1+f*f*36e-6):" ..
                "axisfile".."="..mp.find_config_file("scripts").."/visualizer/axis.png:" ..
                "font"..    "='Nimbus Mono L,Courier New,mono|bold':" ..
                "fontcolor='st(0, (midi(f)-53.5)/12); st(1, 0.5 - 0.5*cos(PI*ld(0))); r(1-ld(1)) + b(ld(1))':" ..
                "tc"..      "=0.33:" ..
                "attack"..  "=0.033 [vo]"


    elseif name == "avectorscope" then
        local px = math.min(w,h)
        return "[aid"..aid.."] asplit [ao]," ..
            "avectorscope".."= " ..
                "mode"..    "=lissajous_xy: " ..
                "mirror"..  "=y: " ..
                "draw"..    "=line: " ..
                -- "rc= 63:gc=255:bc=127:ac=255: " ..
                -- "rf=127:gf=127:bf=127:af=127: " ..
                "rf=32:gf=32:bf=32:af=32: " ..
                "size"..    "="..px.."x"..px..": " ..
                "rate"..    "="..fps..",  " ..
            "format"..      "= rgb0 [vo]"


    elseif name == "avectorscope-dots" then
        local px = math.min(w,h)
        return "[aid"..aid.."] asplit [ao]," ..
            "avectorscope".."= " ..
                "mode"..    "=lissajous_xy: " ..
                "mirror"..  "=y: " ..
                -- "draw"..    "=line: " ..
                "rc= 63:gc=255:bc=127:ac=255: " ..
                -- "rf=127:gf=127:bf=127:af=127: " ..
                "rf=32:gf=32:bf=32:af=32: " ..
                "size"..    "="..px.."x"..px..": " ..
                "rate"..    "="..fps..",  " ..
            "format"..      "= rgb0 [vo]"


    elseif name == "showspectrum" then
        return "[aid"..aid.."] asplit [ao]," ..
            "showspectrum".." =" ..
                "size"..    " ="..w.."x"..h..":" ..
                "win_func".." = blackman [vo]"


    elseif name == "showcqt-bar" then
        local axis_h = math.ceil(w * 12 / 1920) * 4

        return get_visualizer("showcqt")
            :gsub('size=[^:]+','size='..w.."x"..(h + axis_h)/(2))
            :gsub("/axis.png:","/axis48.png:")
            :gsub(' *%[vo%]',":axis_h="..axis_h..":sono_h=0, "..
                "split [v0], crop=h="..(h - axis_h)/(2)..":y=0, vflip, [v0] vstack [vo]")


    elseif name == "showwaves" then
        return "[aid"..aid.."] asplit [ao]," ..
            "showwaves"..   "=" ..
                "size"..    "="..w.."x"..h..":" ..
                "r"..       "=46:" .. -- ~1920px window, traveling left at half that per frame
                "draw"..    "=full:" ..
                "mode"..    "=p2p," ..
            "format"..      "=rgb0 [vo]"

    elseif name == "showwaves-dots" then
        return get_visualizer("showwaves"):gsub('=p2p','=point')

    elseif name == "showwaves-mid" then
        return get_visualizer("showwaves"):gsub('asplit %[ao],','asplit [ao],'
            .. "highpass=f=1024,"
            .. "lowpass=f=4096,"
            )

    elseif name == "showwaves-high" then
        return get_visualizer("showwaves"):gsub('asplit %[ao],','asplit [ao],'
            .. "highpass=f=4096,"
            )

    elseif name == "showwaves-low" then
        return get_visualizer("showwaves"):gsub('asplit %[ao],','asplit [ao],'
            .. "lowpass=f=1024,"
            )


    end

    mp.msg.error("invalid visualizer name")
    return ''
end

local lavfi_save, lavfi_lastset = {}, nil
local function hook()
    mp.msg.debug('hook()')
    aid=tonumber(mp.get_property('aid')) or aid
    if not aid then for _, track in ipairs(mp.get_property_native("track-list")) do
        if track.type == "audio" then
            aid = track.id
            if aid then break end
        end
    end end
    if not aid then
        local function observ()
            mp.msg.debug 'observ'
            mp.unobserve_property(observ)
            hook()
        end
        mp.observe_property('aid','native',observ)
        return
    end
    vid=tonumber(mp.get_property('vid')) or vid
    mp.msg.trace('Passed checks')

    local first_run = not lavfi_lastset
    mp.msg.debug('firstrun:',first_run)
    if first_run then
        if mp.get_property('vid')=='no' then
            opts.name='ao'
            cycle(last_cycleby)
        end
    end

    local lavfi_current = mp.get_property("lavfi-complex")
    if lavfi_current ~= lavfi_lastset then
        table.insert(lavfi_save,lavfi_current)
        mp.msg.debug('lavfi_save: {',table.concat(lavfi_save,', '),'}')
    end

    local lavfi = get_visualizer(opts.name) or ''
    if lavfi ~= lavfi_lastset then
        mp.msg.debug('lavfi before:',lavfi_current or '<none>')
        mp.set_property("lavfi-complex", lavfi)
        lavfi_lastset = lavfi
        mp.msg.debug('lavfi after:', lavfi)
    else
        mp.msg.trace('Not setting lavfi-complex; lavfi==lavfi_lastset')
    end

    if first_run then
        mp.observe_property('osd-dimensions', "native", hook)
        mp.set_property('audio-display','no')
        if mp.get_property('vid')=='no' then
            mp.set_property('vid','auto')
        end
    end
end

if opts.name == 'ao' then vid=tonumber(mp.get_property('vid')) or vid; mp.set_property('vid','no')
elseif opts.name ~= 'av' then mp.add_hook("on_preloaded", 50, hook)
end

mp.add_key_binding(          cycle_key, "cycle+", function() cycle( 1); hook(); end)
mp.add_key_binding('Shift+'..cycle_key, "cycle-", function() cycle(-1); hook(); end)
