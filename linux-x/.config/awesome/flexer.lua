-- Based on wibox.layout.{fixed,flex}
-- Similar to flex, but it will not both stretch and crop children.

local base = require("wibox.widget.base")
local fixed = require("wibox.layout.fixed")
local gmath = require("gears.math")
local gtable = require("gears.table")

local flexer = {}

function flexer:layout(context, width, height)
    local result = {}
    local spacing = self._private.spacing
    local num = #self._private.widgets
    local total_spacing = (spacing * (num - 1))
    local spacing_widget = self._private.spacing_widget
    local abspace = math.abs(spacing)
    local spoffset = spacing < 0 and 0 or spacing
    local is_y = self._private.dir == "y"
    local is_x = not is_y

    local ready = true
    local sum_space_used = 0
    for k, v in pairs(self._private.widgets) do
       if self._private.calculated_space[v] == nil then
          self._private.calculated_space[v] = 0
       end
       sum_space_used = sum_space_used + self._private.calculated_space[v]
    end

    if num == 0 then return result end
    local additional_space = is_x and (width - sum_space_used - total_spacing) / num or (height - sum_space_used - total_spacing) / num
    
    local pos, pos_rounded = 0, 0
    for k, v in pairs(self._private.widgets) do
       local x, y, w, h, next_pos, next_pos_rounded

       next_pos = pos + self._private.calculated_space[v] + additional_space
       next_pos_rounded = k == num and width or gmath.round(next_pos)
       
       if is_y then
          x, y = 0, pos_rounded
          w, h = width, next_pos_rounded - pos_rounded  
       else
          x, y = pos_rounded, 0
          w, h = next_pos_rounded - pos_rounded, height
       end
       
       pos = next_pos + spacing
       pos_rounded = next_pos_rounded + spacing
       
       table.insert(result, base.place_widget_at(v, x, y, w, h))
       
       if k > 1 and spacing ~= 0 and spacing_widget then
          table.insert(result, base.place_widget_at(
                          spacing_widget, is_x and (x - spoffset) or x, is_y and (y - spoffset) or y,
                          is_x and abspace or w, is_y and abspace or h
          ))
       end
    end

    return result
end

function flexer:fit(context, width, height)
   local sum_used_in_dir = 0
   local used_in_dir = {}
   local max_used_in_other = 0

   local spacing = self._private.spacing * (#self._private.widgets-1)
   if self._private_dir == "y" then
      height = height - spacing
      available_in_dir = height
   else
      width = width - spacing
      available_in_dir = width
   end

   if available_in_dir <= 0 then return 0, 0 end
   
   for _, v in pairs(self._private.widgets) do
      local w, h = base.fit_widget(self, context, v, width, height)

      if self._private.dir == "y" then
         if w > max_used_in_other then
            max_used_in_other = w
         end

         if self._private.max_widget_size then
            self._private.calculated_space[v] = math.min(self._private.max_widget_size, h)
         else
            self._private.calculated_space[v] = h
         end
      else
         if h > max_used_in_other then
            max_used_in_other = h
         end

         if self._private.max_widget_size then
            self._private.calculated_space[v] = math.min(self._private.max_widget_size, w)
         else
            self._private.calculated_space[v] = w
         end

      end

      sum_used_in_dir = sum_used_in_dir + self._private.calculated_space[v]
      table.insert(used_in_dir, self._private.calculated_space[v])
   end

   local calculated_max = nil
   local left_in_dir = available_in_dir
   table.sort(used_in_dir)
   for i = 1, #used_in_dir do
      local limit = left_in_dir / (#used_in_dir - i + 1)
      if limit <= used_in_dir[i] then
         calculated_max = limit
         break
      end
      left_in_dir = left_in_dir - used_in_dir[i]
   end

   if calculated_max ~= nil then
      sum_used_in_dir = available_in_dir
      for _, v in pairs(self._private.widgets) do
         if self._private.calculated_space[v] > calculated_max then
            self._private.calculated_space[v] = calculated_max
         end
      end
   end

   if self._private.dir == "y" then
      return max_used_in_other, sum_used_in_dir + spacing
   else
      return sum_used_in_dir + spacing, max_used_in_other
   end
end

function flexer:set_max_widget_size(val)
    if self._private.max_widget_size ~= val then
        self._private.max_widget_size = val
        self:emit_signal("widget::layout_changed")
    end
end

local function get_layout(dir, widget1, ...)
    local ret = fixed[dir](widget1, ...)

    gtable.crush(ret, flexer, true)

    ret._private.fill_space = nil
    ret._private.calculated_space = {}
    setmetatable(ret._private.calculated_space, { __mode = "k" })

    return ret
end

function flexer.horizontal(...)
    return get_layout("horizontal", ...)
end

function flexer.vertical(...)
    return get_layout("vertical", ...)
end

return flexer