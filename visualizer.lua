-- various audio visualization
-- original source: https://github.com/mfcc64/mpv-scripts

-- default settings
-- '_' + setting is override
local opts = {
    name = 'av',
    fps = 48, -- _fps = 48,
    -- width = 960, _width =nil,
    height= 540, _height=nil,
    ratio = 16/9, _ratio=nil,
}
local cycle_key = "v" -- "script-binding visualizer/cycle+"
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
    -- "showwaves-high",
    -- "showwaves-low",
    -- "showcqt-bar",
    -- "showcwt",
    -- "showspectrum-phase",
    -- "showspectrum-legend",
    -- "showspectrum",
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
    local basename = opts.name:match'^[^-]+'
    namelist[namelist_r[basename]]=opts.name -- add new val
    namelist_r[opts.name]=namelist_r[basename] -- add new pointer
    -- namelist_r[basename]=nil
else
    local name = opts.name
    if not namelist_r[name] then
        namelist_r[name] = #namelist+1
        namelist[namelist_r[name]] = name
    end
end

local aid,vid
local aon,von

local function get_visualizer(name)
    -- https://ffmpeg.org/ffmpeg-filters.html

    local osd_dims = mp.get_property_native('osd-dimensions')
    local w, h = opts._width or osd_dims.w~=0 and osd_dims.w or opts.width,  opts._height or osd_dims.h~=0 and osd_dims.h or opts.height
    if not w and not h then
        mp.msg.error("invalid size")
        return
    end
    w, h = w or h*opts.ratio, h or w/opts.ratio
    if opts._ratio and w/h~=opts._ratio then -- todo? make it approx match
        local r = opts._ratio
        local a, b, c = {w=w,h=w/r}, {w=h*r,h=h}, {w=w,h=h}
        a.a=a.w*a.h
        b.a=b.w*b.h
        c.a=c.w*c.h
        a.d=math.abs(a.a-c.a)
        b.d=math.abs(b.a-c.a)
        if a.d<b.d then
            w,h=a.w,a.h
        elseif b.d<a.d then
            w,h=b.w,b.h
        else
            w,h=math.floor((a.w+b.w)/2),math.floor((a.h+b.h)/2)
        end
    end

    local fps = opts._fps or math.min(mp.get_property_native('display-fps',math.huge), opts.fps) * mp.get_property_native('speed',1)
    if fps==0 or not w or not h then
        mp.msg.error("invalid quality")
        return
    end

    if false then --noop
    elseif name == 'ao' then
        mp.set_property("lavfi-complex", "")
        mp.set_property("aid", 0)
        mp.set_property("aid", aid)
        mp.set_property("vid", "no")
        return ""


    elseif name == "av" then
        for _, track in ipairs(vid and {} or mp.get_property_native("track-list")) do
            if vid then break end
            if track.type == "video" then
                vid = track.id
            end
            if vid then break end
        end
        if vid then
            mp.set_property("lavfi-complex", "")
            mp.set_property("aid", 0)
            mp.set_property("aid", aid)
            mp.set_property("vid", 0)
            mp.set_property("vid", vid)
            return ""
        else
            return get_visualizer(cycle(last_cycleby))
        end


    elseif name == "showcqt" then
        return "[aid"..aid.."] asplit [ao]," ..
            "showcqt"..     "=" ..
                "fps"..     "="..fps..":" ..
                "size"..    "="..(math.floor(w/2)*2).."x"..(math.floor(h/2)*2)..":" ..
                "count"..   "="..math.ceil(h /12 /fps)..":" .. -- 1/rate downward, min 1
                "bar_g"..   "=2:" ..
                "sono_g"..  "=4:" ..
                "bar_v"..   "=sono_v*9/17:" ..
                "sono_v"..  "=17*0.95*(f*6e-3)/sqrt(1+f*f*36e-6):"..-- ≈16.15*(1-exp(-f*6e-3))
                "font"..    "=mono|bold:" ..
                "fontcolor='r(.533)+g(1)+b(if(between(mod(midi(f)+.5,48),12,24), 1, .6))':"..--C4
                "tc"..      "=0.33:" ..
                "attack"..  "=0.033 [vo]"

    elseif name == "showcqt-bar" then
        local axis_h = math.ceil(w * 12 / 1920) * 4

        return get_visualizer("showcqt")
            :gsub('size=[^:]+','size='..w.."x"..(h + axis_h)/(2))
            :gsub(' *%[vo]',":axis_h="..axis_h..":sono_h=0, "..
                "split [v0], crop=h="..(h - axis_h)/(2)..":y=0, vflip, [v0] vstack [vo]")


    elseif name == "showcwt" then
        return "[aid"..aid.."] asplit [ao], " ..
            "showcwt=" ..
                "rate="..fps..":" ..
                "size="..w.."x"..h..":" ..
                "direction=du:" ..
                "mode=stereo:"..
                "bar=0.25:"..
                -- "bar="..(1/h)..":"..
                "pps="..math.ceil(h /12)..":" ..
                "deviation=10:"..
                "logb=0.001:"..
                "scale=log [vo]"


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
        return "[aid"..aid.."] asplit [ao], " ..
            "showspectrum=" ..
                "size".."="..w.."x"..h..":" ..
                "fscale".."=log:"..
                "slide=lreplace:"..
                "orientation=horizontal:"..
                "rotation=-0.25:"..
                "saturation=0.5:"..
                "scale=5thrt:"..
                -- "=:"..
                "win_func=blackman [vo]"

    elseif name == "showspectrum-phase" then
        return get_visualizer("showspectrum"):gsub('fscale=log','data=phase')

    elseif name == "showspectrum-legend" then
        local w,h = w-282-16, h-128
        return get_visualizer("showspectrum"):gsub('size=[0-9]+x[0-9]+:','size='..w..'x'..h..':legend=enabled:')


    elseif name == "showwaves" then
        return "[aid"..aid.."] asplit [ao]," ..
            "showwaves".."=" ..
                "size".. "="..w.."x"..h..":" ..
                "r"..    "=46:" .. -- ~1920px window, traveling left at half that per frame
                "draw".. "=full:" ..
                "mode".. "=p2p," ..
            "format"..   "=rgb0 [vo]"

    elseif name == "showwaves-dots" then
        return get_visualizer("showwaves"):gsub('mode=p2p','mode=point')

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
local function hook(prop)
    mp.msg.debug('hook()')
    if prop=='osd-dimensions' and lavfi_lastset=='' then return end
    aid=tonumber(mp.get_property('aid')) or aid
    if not aid then for _, track in ipairs(mp.get_property_native("track-list")) do
        if track.type == "audio" then
            aid = track.id
            if aid then break end
        end
    end end
    if not aid then
        local function observ()--_,aid)
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
    if first_run then
        mp.msg.debug 'first run'
        if mp.get_property('vid')=='no' then
            -- TODO this probably could have a better condition
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
    if lavfi ~= lavfi_current then
        mp.msg.debug('lavfi before:',lavfi_current or '<none>')
        mp.set_property("lavfi-complex", lavfi)
        lavfi_lastset = lavfi
        mp.msg.info('lavfi after:', lavfi)
    else
        mp.msg.trace('Not setting lavfi-complex; lavfi==lavfi_current')
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

-- v script-binding visualizer/cycle+
mp.add_key_binding(          cycle_key, "cycle+", function() cycle( 1); hook(); end)
mp.add_key_binding('Shift+'..cycle_key, "cycle-", function() cycle(-1); hook(); end)
