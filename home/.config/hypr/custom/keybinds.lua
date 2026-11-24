local bind = require("modules.keybinds")

-- Resize the focused window vertically in logical pixels.
bind("SUPER + ALT + up", hl.dsp.window.resize({ x = 0, y = 40, relative = true }),
    { repeating = true, description = "Увеличить высоту окна" })
bind("SUPER + ALT + down", hl.dsp.window.resize({ x = 0, y = -40, relative = true }),
    { repeating = true, description = "Уменьшить высоту окна" })

bind("SUPER + ALT + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }),
    { repeating = true, description = "Уменьшить ширину окна" })

bind("SUPER + ALT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }),
    { repeating = true, description = "Увеличить ширину окна" })

require("modules.switcher-shift")
