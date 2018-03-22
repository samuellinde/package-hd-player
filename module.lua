local localized, CHILDS, CONTENTS = ...

local M = {}

local font = resource.load_font(localized "silkscreen.ttf")
local text = "hey"

print "sub module init"

function M.draw()
    font:write(100, 100, text, 30, 1,1,1,1)
end

function M.unload()
    print "sub module is unloaded"
end

function M.content_update(name)
    print("sub module content update", name)
    if name == 'text.txt' then
        text = resource.load_file(localized(name))
    end
end

function M.content_remove(name)
    print("sub module content delete", name)
end

return M