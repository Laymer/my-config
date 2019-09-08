local capi = {
   screen = screen,
   client = client,
}
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local lgi = require("lgi")
local dpi = require("beautiful.xresources").apply_dpi

-- A waffle view is a table with the following elements
--   .widget -- the entry widget
--   .key_handler (optional) -- the key handling function. It returns a boolean if the key event is captured.

local function create_view(args)
   local view = {}
   view.keys = {}

   local rows = wibox.widget {
      layout = wibox.layout.fixed.vertical,
   }
   for i, r in ipairs(args.rows or {}) do
      local row_layout = wibox.widget {
         layout = wibox.layout.fixed.horizontal,
      }
      for j, cell in ipairs(r) do
         if cell.key_handler then
            for _, k in ipairs(cell.keys or {}) do
               view.keys[k] = cell.key_handler
            end
         end
         row_layout:add(cell.widget)
      end
      rows:add(row_layout)
   end

   view.widget = rows
   -- wibox.widget {
   --    rows,
   --    left = dpi(10), right = dpi(10), bottom = dpi(10), top = dpi(10),
   --    widget = wibox.container.margin,
   -- }

   view.key_handler = function (mod, key, event)
      if event == "press" and view.keys[key] then
         view.keys[key](mod, key, event)
         return true
      else
         return false
      end
   end

   view.options = {
      -- Options here.
   }

   return view
end

local waffle = {
   create_view = create_view,
   gravity_ = "southwest",
}

waffle.widget_container = wibox.widget {
   fill_vertical = false,
   fill_horizontal = false,
   widget = wibox.container.place,
}
waffle.widget_container:connect_signal(
   "button::press",
   function (_, x, y, button, _, info)
      local f = info.drawable:find_widgets(x, y)
      if #f == 1 then
         -- Only happens only if clicking the empty area
         waffle:hide()
      end
end)

function waffle:update_layout(screen)
   screen = screen or (self.wibox_ and self.wibox_.screen)
   if screen then
      if beautiful.waffle_use_entire_screen then
         self.wibox_:geometry({
               x = screen.geometry.x,
               y = screen.geometry.y,
               width = screen.geometry.width,
               height = screen.geometry.height,
         })
      else
         self.wibox_:geometry({
               x = screen.workarea.x,
               y = screen.workarea.y,
               width = screen.workarea.width,
               height = screen.workarea.height,
         })
      end
   end

   if self.wibox_ and self.wibox_.widget == nil then
      self.wibox_.widget = self.widget_container
   end

   if self.gravity_ == "center" then
      self.widget_container.valign = "center"
      self.widget_container.halign = "center"
   elseif self.gravity_ == "north" then
      self.widget_container.valign = "top"
      self.widget_container.halign = "center"
   elseif self.gravity_ == "south" then
      self.widget_container.valign = "bottom"
      self.widget_container.halign = "center"
   elseif self.gravity_ == "west" then
      self.widget_container.valign = "center"
      self.widget_container.halign = "left"
   elseif self.gravity_ == "east" then
      self.widget_container.valign = "center"
      self.widget_container.halign = "right"
   elseif self.gravity_ == "northeast" then
      self.widget_container.valign = "top"
      self.widget_container.halign = "right"
   elseif self.gravity_ == "northwest" then
      self.widget_container.valign = "top"
      self.widget_container.halign = "left"
   elseif self.gravity_ == "southeast" then
      self.widget_container.valign = "bottom"
      self.widget_container.halign = "right"
   elseif self.gravity_ == "southwest" then
      self.widget_container.valign = "bottom"
      self.widget_container.halign = "left"
   end
end

function waffle:set_gravity(gravity)
   if self.gravity_ ~= gravity then
      self.gravity_ = gravity
      self:update_layout()
   end
end

function waffle:show(view, push, screen)
   view = view or self.root_view_
   screen = screen or awful.screen.focused()
   if self.wibox_ == nil then
      self.wibox_ = wibox({
            screen = screen,
            x = screen.geometry.x,
            y = screen.geometry.y,
            width = screen.geometry.width,
            height = screen.geometry.height,
            bg = beautiful.waffle_background or (beautiful.bg_normal:sub(1,7) .. "80"),
            opacity = 1,
            ontop = true,
            type = "dock",
      })
   end

   self:update_layout(screen)

   if push then
      self.stack_ = self.stack_ or {}
      table.insert(self.stack_, self.view_)
   end
   self.view_ = view
   self.widget_container.widget = view.widget

   if not self.wibox_.visible then
      self.keygrabber_ = awful.keygrabber.run(
         function (mod, key, event)
            if #key == 1 then
               key = key:lower()
            end
            if self.view_.key_handler and self.view_.key_handler(mod, key, event) then
               -- pass
            elseif key == "Escape" or key == "F12" then
               if event == "press" then
                  self:hide()
               end
            elseif key == "BackSpace" then
               if event == "press" then
                  self:go_back()
               end
            end
         end
      )
      self.wibox_.visible = true
   end
end

function waffle:go_back()
   local headpos = self.stack_ and #self.stack_ or 0
   if headpos >= 1 then
      local last = self.stack_[headpos]
      table.remove(self.stack_, headpos)
      self:show(last, nil, false)
   else
      self:hide()
   end
end

function waffle:hide()
   if self.keygrabber_ ~= nil then
      awful.keygrabber.stop(self.keygrabber_)
      self.keygrabber_ = nil
   end
   if self.wibox_ ~= nil then
      self.wibox_.visible = false
      self.wibox_ = nil
   end
   self.view_ = nil
   self.stack_ = nil
end

function waffle:set_root_view(v)
   self.root_view_ = v
end

return waffle
