local theme = dofile("/usr/share/awesome/themes/zenburn/theme.lua")
local dpi   = require("beautiful.xresources").apply_dpi

theme.font = "Sans 10"
theme.mono_font = "Hack 10"
theme.useless_gap = dpi(8)
theme.bar_height = dpi(20)

return theme
