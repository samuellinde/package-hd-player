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
local font = resource.load_font "roboto.ttf"

function M.draw()
    font:write(100, 100, text, 30, 1,1,1,1)
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