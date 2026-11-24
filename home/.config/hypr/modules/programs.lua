-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   P R O G R A M S                                                        │
-- │   default applications · consumed by other modules                       │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- Single place declaring which program does what. To use it:
--     local apps = require("modules.programs")

local function default_browser()
    local home   = os.getenv("HOME") or ""
    local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
    local file   = io.open(config .. "/mimeapps.list")
    if file then
        local in_default = false
        for line in file:lines() do
            local section = line:match("^%s*%[(.+)%]%s*$")
            if section then
                in_default = (section == "Default Applications")
            elseif in_default then
                local desktop = line:match("^x%-scheme%-handler/https?=(.-);?$")
                    or line:match("^text/html=(.-);?$")
                if desktop and desktop ~= "" then
                    file:close()
                    return "gtk-launch " .. desktop
                end
            end
        end
        file:close()
    end
    return [[gtk-launch "$(xdg-settings get default-web-browser)"]]
end

return {
    terminal     = "kitty -1",
    file_manager = "thunar",

    -- The system default browser, resolved once at config load.
    browser      = default_browser(),
}
