local localized, CHILDS, CONTENTS = ...

local M = {}

local json = require "json"

-- local font = resource.load_font(localized "silkscreen.ttf")
local text = "hey"

print "sub module init"

local shaders = {
    multisample = resource.create_shader[[
        uniform sampler2D Texture;
        varying vec2 TexCoord;
        uniform vec4 Color;
        uniform float x, y, s;
        void main() {
            vec2 texcoord = TexCoord * vec2(s, s) + vec2(x, y);
            vec4 c1 = texture2D(Texture, texcoord);
            vec4 c2 = texture2D(Texture, texcoord + vec2(0.0002, 0.0002));
            gl_FragColor = (c2+c1)*0.5 * Color;
        }
    ]], 
    simple = resource.create_shader[[
        uniform sampler2D Texture;
        varying vec2 TexCoord;
        uniform vec4 Color;
        uniform float x, y, s;
        void main() {
            gl_FragColor = texture2D(Texture, TexCoord * vec2(s, s) + vec2(x, y)) * Color;
        }
    ]], 
    progress = resource.create_shader[[
        uniform sampler2D Texture;
        varying vec2 TexCoord;
        uniform float progress_angle;

        float interp(float x) {
            return 2.0 * x * x * x - 3.0 * x * x + 1.0;
        }

        void main() {
            vec2 pos = TexCoord;
            float angle = atan(pos.x - 0.5, pos.y - 0.5);
            float dist = clamp(distance(pos, vec2(0.5, 0.5)), 0.0, 0.5) * 2.0;
            float alpha = interp(pow(dist, 8.0));
            if (angle > progress_angle) {
                gl_FragColor = vec4(1.0, 1.0, 1.0, alpha);
            } else {
                gl_FragColor = vec4(0.5, 0.5, 0.5, alpha);
            }
        }
    ]]
}

local settings = {
    IMAGE_PRELOAD = 2;
    VIDEO_PRELOAD = 2;
    PRELOAD_TIME = 5;
    FALLBACK_PLAYLIST = {
        {
            offset = 0;
            total_duration = 1;
            duration = 1;
            asset_name = "blank.png";
            type = "image";
        }
    }
}

local white = resource.create_colored_texture(1,1,1,1)
local black = resource.create_colored_texture(0,0,0,1)
local font = resource.load_font(localized "roboto.ttf")

local function ramp(t_s, t_e, t_c, ramp_time)
    if ramp_time == 0 then return 1 end
    local delta_s = t_c - t_s
    local delta_e = t_e - t_c
    return math.min(1, delta_s * 1/ramp_time, delta_e * 1/ramp_time)
end

local function cycled(items, offset)
    offset = offset % #items + 1
    return items[offset], offset
end

local Loading = (function()
    local loading = "Loading..."
    local size = 80
    local w = font:width(loading, size)
    local alpha = 0
    
    local function draw()
        if alpha == 0 then
            return
        end
        font:write((WIDTH-w)/2, (HEIGHT-size)/2, loading, size, 1,1,1,alpha)
    end

    local function fade_in()
        alpha = math.min(1, alpha + 0.01)
    end

    local function fade_out()
        alpha = math.max(0, alpha - 0.01)
    end

    return {
        fade_in = fade_in;
        fade_out = fade_out;
        draw = draw;
    }
end)()

local Config = (function()
    local playlist = {}
    local switch_time = 1
    local synced = false
    local kenburns = false
    local audio = false
    local portrait = false
    local rotation = 0
    local transform = function() end

    local config_file = "config.json"

    -- You can put a static-config.json file into the package directory.
    -- That way the config.json provided by info-beamer hosted will be
    -- ignored and static-config.json is used instead.
    --
    -- This allows you to import this package bundled with images/
    -- videos and a custom generated configuration without changing
    -- any of the source code.
    if CONTENTS["static-config.json"] then
        config_file = "static-config.json"
        print "[WARNING]: will use static-config.json, so config.json is ignored"
    end

    util.file_watch(config_file, function(raw)
        print("updated " .. config_file)
        local config = json.decode(raw)

        synced = config.synced
        kenburns = config.kenburns
        audio = config.audio
        progress = config.progress

        rotation = config.rotation
        portrait = rotation == 90 or rotation == 270
        gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)
        transform = util.screen_transform(rotation)
        print("screen size is " .. WIDTH .. "x" .. HEIGHT)

        if #config.playlist == 0 then
            playlist = settings.FALLBACK_PLAYLIST
            switch_time = 0
            kenburns = false
        else
            playlist = {}
            local total_duration = 0
            for idx = 1, #config.playlist do
                local item = config.playlist[idx]
                total_duration = total_duration + item.duration
            end

            local offset = 0
            for idx = 1, #config.playlist do
                local item = config.playlist[idx]
                if item.duration > 0 then
                    playlist[#playlist+1] = {
                        offset = offset,
                        total_duration = total_duration,
                        duration = item.duration,
                        asset_name = item.file.asset_name,
                        type = item.file.type,
                    }
                    offset = offset + item.duration
                end
            end
            switch_time = config.switch_time
        end
    end)

    return {
        get_playlist = function() return playlist end;
        get_switch_time = function() return switch_time end;
        get_synced = function() return synced end;
        get_kenburns = function() return kenburns end;
        get_audio = function() return audio end;
        get_progress = function() return progress end;
        get_rotation = function() return rotation, portrait end;
        apply_transform = function() return transform() end;
    }
end)()

local Intermissions = (function()
    local intermissions = {}
    local intermissions_serial = {}

    util.file_watch("intermission.json", function(raw)
        intermissions = json.decode(raw)
    end)

    local serial = sys.get_env "SERIAL"
    if serial then
        util.file_watch("intermission-" .. serial .. ".json", function(raw)
            intermissions_serial = json.decode(raw)
        end)
    end

    local function get_playlist()
        local now = os.time()
        local playlist = {}

        local function add_from_intermission(intermissions)
            for idx = 1, #intermissions do
                local intermission = intermissions[idx]
                if intermission.starts <= now and now <= intermission.ends then
                    playlist[#playlist+1] = {
                        duration = intermission.duration,
                        asset_name = intermission.asset_name,
                        type = intermission.type,
                    }
                end
            end
        end

        add_from_intermission(intermissions)
        add_from_intermission(intermissions_serial)

        return playlist
    end

    return {
        get_playlist = get_playlist;
    }
end)()

local Scheduler = (function()
    local playlist_offset = 0

    local function get_next()
        local playlist = Intermissions.get_playlist()
        if #playlist == 0 then
            playlist = Config.get_playlist()
        end

        local item
        item, playlist_offset = cycled(playlist, playlist_offset)
        print(string.format("next scheduled item is %s [%f]", item.asset_name, item.duration))
        return item
    end

    return {
        get_next = get_next;
    }
end)()

function M.draw()
    font:write(100, 100, text, 60, 1,1,1,1)
end

function M.unload()
    print "sub module is unloaded"
end

function M.content_update(name)
    print("sub module content update", name)
    -- if name == 'text.txt' then
    --     text = resource.load_file(localized(name))
    -- end
    text = sys.now()
end

function M.content_remove(name)
    print("sub module content delete", name)
end

return M