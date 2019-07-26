local awful  = require("awful")
local be     = require("beautiful")
local gshape = require("gears.shape")
local wi     = require("wibox")
local dpi    = require("beautiful.xresources").apply_dpi

be.init("~/.config/awesome/theme.lua")

be.tasklist_shape = function(cr, w, h)
   offset = h / 4
   cr:move_to(0, 0)
   cr:line_to(w, 0)
   cr:line_to(w - offset, h)
   cr:line_to(offset, h)
   cr:close_path()
end
-- be.tasklist_shape_focus = gshape.powerline

local config = {
   tag_filter = function (name)
      return name ~= "STICKY"
   end,
   cmd_terminal = "urxvt",
   cmd_file_manager = "thunar",
}

config.tasklist_template = {
   {
      {
         {
            {
               id     = "clienticon",
               widget = awful.widget.clienticon,
            },
            -- id = "icon_margin_role",
            margins = dpi(1),
            widget  = wi.container.margin,
         },
         {
            id     = "text_role",
            widget = wi.widget.textbox,
         },
         layout = wi.layout.fixed.horizontal,
      },
      id = "text_margin_role",
      left  = dpi(5),
      right = dpi(5),
      widget = wi.container.margin
   },
   id     = "background_role",
   widget = wi.container.background,
}

return config
