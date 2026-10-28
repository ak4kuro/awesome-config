-----------------------------------------------------------------------------------------------------------------------
--                                                   RedFlat tag widget                                              --
-----------------------------------------------------------------------------------------------------------------------
-- Custom widget to display tag info
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local math = math

local wibox = require("wibox")
local beautiful = require("beautiful")
local color = require("gears.color")
local shape = require("gears.shape")

local redutil = require("redflat.util")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local jiyutag = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		width        = 50,
		base = { pad = 5, height = 12, thickness = 2 },
		mark = { pad = 10, height = 4 },
		color        = { main  = "#b1222b", gray  = "#575757", icon = "#a0a0a0", urgent = "#32882d" }
	}

	-- Radio por defecto para las esquinas redondeadas.
	style.base.radius = style.base.height / 2
	style.mark.radius = style.mark.height / 2

	return redutil.table.merge(style, redutil.table.check(beautiful, "gauge.tag.Jiyu") or {})
end

-- Create a new tag widget
-- @param style Table containing colors and geometry parameters for all elemets
-----------------------------------------------------------------------------------------------------------------------
function jiyutag.new(style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	style = redutil.table.merge(default_style(), style or {})

	-- updating values
	local data = {
		width = style.width or nil
	}

	-- Create custom widget
	--------------------------------------------------------------------------------
	local widg = wibox.widget.base.make_widget()

	-- User functions
	------------------------------------------------------------
	function widg:set_state(state)
		data.state = state
		self:emit_signal("widget::redraw_needed")
	end

	function widg:set_width(width)
		data.width = width
		self:emit_signal("widget::redraw_needed")
	end

	-- Fit
	------------------------------------------------------------
	function widg:fit(_, width, height)
		if data.width then
			return math.min(width, data.width), height
		else
			return width, height
		end
	end

	-- Draw
	------------------------------------------------------------
	function widg:draw(_, cr, width, height)

		-- state
		local cl = data.state.active and style.color.main or style.color.gray
		cr:set_source(color(cl))

		local bx = style.base.pad
		local by = math.floor((height - style.base.height) / 2)
		local bw = width - 2 * style.base.pad
		local bh = style.base.height

		cr:save()
		cr:translate(bx, by)
		shape.rounded_rect(cr, bw, bh, style.base.radius)
		cr:set_line_width(style.base.thickness)
		cr:stroke()
		cr:restore()

		-- focus
		cl = data.state.focus and style.color.main
		     or data.state.urgent and style.color.urgent
		     or (data.state.occupied and  style.color.icon or style.color.gray)
		cr:set_source(color(cl))

		local mx = style.mark.pad
		local my = math.floor((height - style.mark.height) / 2)
		local mw = width - 2 * style.mark.pad
		local mh = style.mark.height

		cr:save()
		cr:translate(mx, my)
		shape.rounded_rect(cr, mw, mh, style.mark.radius)
		cr:fill()
		cr:restore()
	end

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call jiyutag module as function
-----------------------------------------------------------------------------------------------------------------------
function jiyutag.mt:__call(...)
	return jiyutag.new(...)
end

return setmetatable(jiyutag, jiyutag.mt)
