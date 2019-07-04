-- Machi, a static and yet configurable layout

local capi = {
   beautiful = require("beautiful"),
   wibox = require("wibox"),
   awful = require("awful"),
   screen = require("awful.screen"),
   layout = require("awful.layout"),
   utils = require("my-utils"),
   keygrabber = require("awful.keygrabber"),
   naughty = require("naughty"),
   gears = require("gears"),
}

local gap = capi.beautiful.useless_gap or 0
local label_font_family = capi.beautiful.get_font(capi.beautiful.font):get_family()
-- colors are in rgba
local border_color = "#ffffffc0"
local active_color = "#6c7ea780"
local open_color   = "#ffffff80"
local closed_color = "#00000080"
local init_max_depth = 2

function region(x, y, w, h)
   return {x = x, y = y, width = w, height = h}
end

function do_arrange(p, priv)
   local wa = p.workarea
   local cls = p.clients
   local regions = priv.regions

   for i, c in ipairs(cls) do
      if c.floating then
         print("Ignore client " .. tostring(c))
      else
         local region
         if c.machi_region == nil then
            c.machi_region = 1
            region = 1
         elseif c.machi_region > #regions or c.machi_region <= 1 then
            region = 1
         else
            region = c.machi_region
         end

         p.geometries[c] = {
            x = regions[region].x,
            y = regions[region].y,
            width = regions[region].width,
            height = regions[region].height,
         }

         print("Put client " .. tostring(c) .. " to region " .. region)

      end
   end
end

function create_layout(name, regions)
   local priv = {}

   local function set_regions(regions)
      priv.regions = regions
   end

   local function get_regions()
      return priv.regions
   end

   set_regions(regions)

   return {
      name = "machi[" .. name .. "]",
      arrange = function (p) do_arrange(p, priv) end,
      get_region_count = function () return #priv.regions end,
      set_regions = set_regions,
      get_regions = get_regions,
   }
end

function set_region(c, r)
   c.floating = false
   c.maximized = false
   c.fullscreen = false
   c.machi_region = r
   capi.layout.arrange(c.screen)
end

function min(a, b)
   if a < b then return a else return b end
end

function max(a, b)
   if a < b then return b else return a end
end

-- find the best region for the area
function fit_region(c, regions)
   local choice = 1
   local choice_value = nil
   local c_area = c.width * c.height
   for i, a in ipairs(regions) do
      local x_cap = max(0, min(c.x + c.width, a.x + a.width) - max(c.x, a.x))
      local y_cap = max(0, min(c.y + c.height, a.y + a.height) - max(c.y, a.y))
      local cap = x_cap * y_cap
      -- -- a cap b / a cup b
      -- local cup = c_area + a.width * a.height - cap
      -- if cup > 0 then
      --    local itx_ratio = cap / cup
      --    if choice_value == nil or choice_value < itx_ratio then
      --       choice_value = itx_ratio
      --       choice = i
      --    end
      -- end
      -- a cap b
      if choice_value == nil or choice_value < cap then
         choice = i
         choice_value = cap
      end
   end
   return choice
end

function cycle_region(c)
   layout = capi.layout.get(c.screen)
   regions = layout.get_regions and layout.get_regions()
   if type(regions) ~= "table" or #regions < 1 then
      c.float = true
      return
   end
   current_region = c.machi_region or 1
   if not capi.utils.is_tiling(c) then
      -- find out which region has the most intersection, calculated by a cap b / a cup b 
      c.machi_region = fit_region(c, regions)
      capi.utils.set_tiling(c)
   elseif current_region >= #regions then
      c.machi_region = 1
   else
      c.machi_region = current_region + 1
   end
   capi.layout.arrange(c.screen)
end

function _area_tostring(wa)
   return "{x:" .. tostring(wa.x) .. ",y:" .. tostring(wa.y) .. ",w:" .. tostring(wa.width) .. ",h:" .. tostring(wa.height) .. "}"
end

function shrink_area_with_gap(a, gap)
   return { x = a.x + (a.bl and 0 or gap / 2), y = a.y + (a.bu and 0 or gap / 2),
            width = a.width - (a.bl and 0 or gap / 2) - (a.br and 0 or gap / 2),
            height = a.height - (a.bu and 0 or gap / 2) - (a.bd and 0 or gap / 2) }
end

function interactive_layout_edit()
   local screen = capi.screen.focused()
   local init_area = {
      x = screen.workarea.x,
      y = screen.workarea.y,
      width = screen.workarea.width,
      height = screen.workarea.height,
      border = 15,
      depth = 0,
      -- we do not want to rely on bitop
      bl = true, br = true, bu = true, bd = true,
   }
   local kg
   local closed_areas = {}
   local open_areas = {init_area}
   local history = {} -- {closed_area size, open_areas size, removed open areas, cmd, max_depth}
   print("interactive layout editing starts")
   local split = nil
   local ratio_lu = nil
   local ratio_rd = nil
   local max_depth = init_max_depth
   local infobox = capi.wibox({
         x = screen.workarea.x,
         y = screen.workarea.y,
         width = screen.workarea.width,
         height = screen.workarea.height,
         bg = "#ffffff00",
         opacity = 1,
         ontop = true
   })
   infobox.visible = true
   local current_cmd = ""

   local function draw_info(context, cr, width, height)
      cr:set_source_rgba(0, 0, 0, 0)
      cr:rectangle(0, 0, width, height)
      cr:fill()

      local msg, ext

      for i, a in ipairs(closed_areas) do
         local sa = shrink_area_with_gap(a, gap)
         cr:rectangle(sa.x, sa.y, sa.width, sa.height)
         cr:clip()
         cr:set_source(capi.gears.color(closed_color))
         cr:rectangle(sa.x, sa.y, sa.width, sa.height)
         cr:fill()
         cr:set_source(capi.gears.color(border_color))
         cr:rectangle(sa.x, sa.y, sa.width, sa.height)
         cr:set_line_width(10.0)
         cr:stroke()

         cr:select_font_face(label_font_family, "normal", "normal")
         cr:set_font_size(30)
         cr:set_font_face(cr:get_font_face())
         msg = tostring(i)
         ext = cr:text_extents(msg)
         cr:set_source_rgba(1, 1, 1, 1)
         cr:move_to(sa.x + sa.width / 2 - ext.width / 2 - ext.x_bearing, sa.y + sa.height / 2 - ext.height / 2 - ext.y_bearing)
         cr:show_text(msg)
         cr:reset_clip()
      end

      for i, a in ipairs(open_areas) do
         local sa = shrink_area_with_gap(a, gap)
         cr:rectangle(sa.x, sa.y, sa.width, sa.height)
         cr:clip()
         cr:set_source(capi.gears.color(i == #open_areas and active_color or open_color) )
         cr:rectangle(sa.x, sa.y, sa.width, sa.height)
         cr:fill()

         cr:set_source(capi.gears.color(border_color))
         cr:rectangle(sa.x, sa.y, sa.width, sa.height)
         cr:set_line_width(10.0)
         cr:stroke()
         cr:reset_clip()
      end

      cr:select_font_face(label_font_family, "normal", "normal")
      cr:set_font_size(60)
      cr:set_font_face(cr:get_font_face())
      msg = current_cmd
      ext = cr:text_extents(msg)
      cr:move_to(width / 2 - ext.width / 2 - ext.x_bearing, height / 2 - ext.height / 2 - ext.y_bearing)
      cr:text_path(msg)
      cr:set_source_rgba(1, 1, 1, 1)
      cr:fill()
      cr:move_to(width / 2 - ext.width / 2 - ext.x_bearing, height / 2 - ext.height / 2 - ext.y_bearing)
      cr:text_path(msg)
      cr:set_source_rgba(0, 0, 0, 1)
      cr:set_line_width(2.0)
      cr:stroke()
   end

   local function push_history()
      history[#history + 1] = {#closed_areas, #open_areas, {}, current_cmd, max_depth, ratio_lu, ratio_rd}
   end

   local function pop_history()
      if #history == 0 then return end
      for i = history[#history][1] + 1, #closed_areas do
         table.remove(closed_areas, #closed_areas)
      end

      for i = history[#history][2] + 1, #open_areas do
         table.remove(open_areas, #open_areas)
      end

      for i = 1, #history[#history][3] do
         open_areas[history[#history][2] - i + 1] = history[#history][3][i]
      end

      current_cmd = history[#history][4]
      max_depth = history[#history][5]
      ratio_lu = history[#history][6]
      ratio_rd = history[#history][7]

      table.remove(history, #history)
   end

   local function pop_open_area()
      local a = open_areas[#open_areas]
      table.remove(open_areas, #open_areas)
      local idx = history[#history][2] - #open_areas
      -- only save when the position has been firstly poped
      if idx > #history[#history][3] then
         history[#history][3][#history[#history][3] + 1] = a
      end
      return a
   end

   local function refresh()
      print("closed areas:")
      for i, a in ipairs(closed_areas) do
         print("  " .. _area_tostring(a))
      end
      print("open areas:")
      for i, a in ipairs(open_areas) do
         print("  " .. _area_tostring(a))
      end
      infobox.bgimage = draw_info
   end

   local function handle_split(method, alt)
      if ratio_lu == nil then ratio_lu = 1 end
      if ratio_rd == nil then ratio_rd = 1 end

      if alt then
         local tmp = ratio_lu
         ratio_lu = ratio_rd
         ratio_rd = tmp
      end

      local a = pop_open_area()
      local lu, rd

      print("split " .. method .. " " .. tostring(alt) .. " " .. _area_tostring(a))

      if method == "h" then
         lu = {
            x = a.x, y = a.y,
            width = a.width / (ratio_lu + ratio_rd) * ratio_lu, height = a.height,
            depth = a.depth + 1,
            bl = a.bl, br = false, bu = a.bu, bd = a.bd,
         }
         rd = {
            x = a.x + lu.width, y = a.y,
            width = a.width - lu.width, height = a.height,
            depth = a.depth + 1,
            bl = false, br = a.br, bu = a.bu, bd = a.bd,
         }
         open_areas[#open_areas + 1] = rd
         open_areas[#open_areas + 1] = lu
      elseif method == "v" then
         lu = {
            x = a.x, y = a.y,
            width = a.width, height = a.height / (ratio_lu + ratio_rd) * ratio_lu,
            depth = a.depth + 1,
            bl = a.bl, br = a.br, bu = a.bu, bd = false
         }
         rd = {
            x = a.x, y = a.y + lu.height,
            width = a.width, height = a.height - lu.height,
            depth = a.depth + 1,
            bl = a.bl, br = a.br, bu = false, bd = a.bd,
         }
         open_areas[#open_areas + 1] = rd
         open_areas[#open_areas + 1] = lu
      elseif method == "w" then
         local x_interval = a.width / ratio_lu
         local y_interval = a.height / ratio_rd
         for y = ratio_rd, 1, -1 do
            for x = ratio_lu, 1, -1 do
               local r = {
                  x = a.x + x_interval * (x - 1),
                  y = a.y + y_interval * (y - 1),
                  width = x_interval,
                  height = y_interval,
                  depth = a.depth + 1
               }
               if x == 1 then r.bl = a.bl else r.bl = false end
               if x == ratio_lu then r.br = a.br else r.br = false end
               if y == 1 then r.bu = a.bu else r.bu = false end
               if y == ratio_rd then r.bd = a.bd else r.bd = false end
               open_areas[#open_areas + 1] = r
            end
         end
      end

      ratio_lu = nil
      ratio_rd = nil
   end

   local function cleanup()
      infobox.visible = false
   end

   local function push_area()
      closed_areas[#closed_areas + 1] = pop_open_area()
      infobox.bgimage = draw_info
   end

   refresh()

   kg = keygrabber.run(function (mod, key, event)
         if event == "release" then
            return
         end

         local to_exit = false
         local to_apply = false

         if key == "h" then
            push_history()
            current_cmd = current_cmd .. "h"
            handle_split("h", false)
         elseif key == "H" then
            push_history()
            current_cmd = current_cmd .. "H"
            handle_split("h", true)
         elseif key == "v" then
            push_history()
            current_cmd = current_cmd .. "v"
            handle_split("v", false)
         elseif key == "V" then
            push_history()
            current_cmd = current_cmd .. "V"
            handle_split("v", true)
         elseif key == "w" then
            push_history()
            current_cmd = current_cmd .. "w"
            handle_split("w", false)
         elseif key == "W" then
            push_history()
            current_cmd = current_cmd .. "W"
            handle_split("w", false)
         elseif key == " " or key == "." then
            push_history()
            current_cmd = current_cmd .. "."
            if ratio_lu ~= nil then
               max_depth = ratio_lu
               ratio_lu = nil
               ratio_rd = nil
            else
               push_area()
               if #open_areas == 0 then
                  to_exit = true
                  to_apply = true
               end
            end
         elseif key == "Return" then
            push_history()
            while #open_areas > 0 do
               push_area()
            end
            to_exit = true
            to_apply = true
         elseif tonumber(key) ~= nil then
            push_history()
            current_cmd = current_cmd .. key
            local v = tonumber(key)
            if v > 0 then
               if ratio_lu == nil then
                  ratio_lu = v
               elseif ratio_rd == nil then
                  ratio_rd = v
               end
            end
         elseif key == "BackSpace" then
            pop_history()
         elseif key == "Escape" then
            to_exit = true
         end

         while #open_areas > 0 and open_areas[#open_areas].depth >= max_depth do
            push_area()
         end

         refresh()

         if #open_areas == 0 then
            to_exit = true
            to_apply = true
         end

         if to_exit then
            print("interactive layout editing ends")
            if to_apply then
               layout = capi.layout.get(screen)
               if layout.set_regions then
                  local areas_with_gap = {}
                  for _, a in ipairs(closed_areas) do
                     areas_with_gap[#areas_with_gap + 1] = shrink_area_with_gap(a, gap)
                  end
                  layout.set_regions(areas_with_gap)
                  capi.layout.arrange(screen)
               end
               capi.gears.timer{
                  timeout = 1,
                  autostart = true,
                  singleshot = true,
                  callback = cleanup
               }
            else
               cleanup()
            end
            keygrabber.stop(kg)
            return
         end
   end)
end

return
   {
      region = region,
      create_layout = create_layout,
      set_region = set_region,
      cycle_region = cycle_region,
      interactive_layout_edit = interactive_layout_edit,
   }