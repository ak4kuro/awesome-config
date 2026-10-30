-----------------------------------------------------------------------------------------------------------------------
--                                               Titlebar config                                                     --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful      = require("awful")
local wibox      = require("wibox")
local beautiful  = require("beautiful")
local color      = require("gears.color")

-- local redflat = require("redflat")
local redtitle   = require("redflat.titlebar")
local redutil    = require("redflat.util")
local clientmenu = require("redflat.float.clientmenu")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local titlebar = {}

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function construct_move_buttons(c, btn)
	return awful.button({ }, btn or 1, function() client.focus = c; c:raise() awful.mouse.client.move(c) end)
end
local function construct_menu_buttons(c, btn)
	return awful.button({ }, btn or 1, function() client.focus = c; c:raise() clientmenu:show(c) end)
end
local function construct_all_buttons(c, move_btn, menu_btn)
	return awful.util.table.join(construct_move_buttons(c, move_btn), construct_menu_buttons(c, menu_btn))
end

local function on_maximize(c)
	-- hide/show title bar
	local is_max = c.maximized_vertical or c.maximized
	local action = is_max and "cut_all" or "restore_all"
	redtitle[action]({ c })

	-- dirty size correction
	local model = redtitle.get_model(c)
	if model and not model.hidden then
		c.height = c:geometry().height + (is_max and model.size or -model.size)
		if is_max then
			c.y = c.screen.workarea.y
		end
	end
end

-- Custom titlebar elements
-----------------------------------------------------------------------------------------------------------------------
-- Asegurar .color.main / .gray / .icon / .urgent sin sustituir el resto del tema (wibox, text, highlight…)
local function ensure_mark_style(st)
	local bc = beautiful.color or {}
	local out = (st and type(st) == "table") and st or {}
	local c = out.color
	if type(c) ~= "table" then
		c = {}
	end
	out.color = redutil.table.merge(redutil.table.merge({}, bc), c)
	if not out.color.main then out.color.main = bc.main or "#0066CC" end
	if not out.color.gray then out.color.gray = bc.gray or "#666666" end
	if not out.color.icon then out.color.icon = bc.icon or "#ffffff" end
	if not out.color.urgent and bc.urgent then out.color.urgent = bc.urgent end
	return out
end

local compact_focus = function(c, style)
	style = ensure_mark_style(style)
	local focus = redtitle.mark.focus(c, style)

	function focus:draw(_, cr, width, height)
		local d = math.tan(self._style.angle) * height

		cr:set_source(color(self._data.color))
		cr:move_to(0, height)
		cr:rel_line_to(d, -height)
		cr:rel_line_to(width - d, 0)
		cr:rel_line_to(0, height)
		cr:close_path()
		cr:fill()
	end

	return focus
end

-- Laterales rojos rellenos con hueco central para los tres controles
local function focus_split_strip(c, style, hole_width)
	style = ensure_mark_style(style)
	local widg = wibox.widget.base.make_widget()
	widg._data = { color = style.color.main }
	widg._style = style
	widg._hole_w = hole_width

	function widg:fit(_, _, width, height)
		return width, height
	end

	function widg:draw(_, cr, width, height)
		local cx = width / 2
		local half = self._hole_w / 2
		local left_w = math.max(0, cx - half)
		local right_x = cx + half
		local right_w = math.max(0, width - right_x)
		local col = color(self._data.color)
		cr:set_source(col)
		-- laterales rellenos en rojo
		cr:rectangle(0, 0, left_w, height)
		cr:fill()
		cr:rectangle(right_x, 0, right_w, height)
		cr:fill()
	end

	widg:buttons(awful.button({}, 3, function()
		client.focus = c
		c:raise()
		clientmenu:show(c)
	end))
	return widg
end

-- Minimal line button for mini titlebar (always gray)
local function line_action_button(c, style, on_click)
	style = ensure_mark_style(style)
	local widg = wibox.widget.base.make_widget()
	widg._style = style
	widg._hover = false
	local BTN_W = 16
	local BTN_H = 14
	local LINE_W = 14

	function widg:fit(_, _, _)
		return BTN_W, BTN_H
	end

	function widg:draw(_, cr, width, height)
		local line_w = math.min(LINE_W, width)
		local line_h = 3
		local x = math.floor((width - line_w) / 2)
		local y = math.floor((height - line_h) / 2)
		local col = self._hover and self._style.color.main or self._style.color.gray
		cr:set_source(color(col))
		cr:rectangle(x, y, line_w, line_h)
		cr:fill()
	end
	widg:connect_signal("mouse::enter", function()
		widg._hover = true
		widg:emit_signal("widget::redraw_needed")
	end)
	widg:connect_signal("mouse::leave", function()
		widg._hover = false
		widg:emit_signal("widget::redraw_needed")
	end)
	widg:buttons(awful.button({}, 1, function()
		client.focus = c
		c:raise()
		on_click(c)
	end))

	return widg
end

-- Window title for left red area in mini titlebar
local function mini_left_title(c, style)
	style = ensure_mark_style(style)
	local tb = wibox.widget.textbox()
	tb.align = "left"
	tb.valign = "center"
	tb.ellipsize = "end"
	tb.font = "Lato 8"

	local function refresh()
		local name = awful.util.escape(c.name or "")
		local fg = (style.color.text or "#FFFFFF")
		tb.markup = string.format("<span foreground='%s'>%s</span>", fg, name)
	end

	refresh()
	c:connect_signal("property::name", refresh)

	return wibox.widget({
		tb,
		forced_width = 140,
		widget = wibox.container.constraint,
		strategy = "max",
	})
end

local function mini_left_title_compact(c, style)
	return wibox.widget({
		mini_left_title(c, style),
		left = 6,
		right = 4,
		widget = wibox.container.margin,
	})
end

-- Connect titlebar building signal
-----------------------------------------------------------------------------------------------------------------------
function titlebar:init()

	local style = {}

	-- titlebar schemes
	-- Mini barra central: 8 px de alto deja los botones (SVG) en ~0 px visibles; 22 px caben 3 iconos como antes.
	style.base    = redutil.table.merge(redutil.table.check(beautiful, "titlebar.base") or {}, { size = 12 })
	style.compact = redutil.table.merge(style.base, { size = 12 })
	style.iconic  = redutil.table.merge(style.base, { size = 12 })

	-- titlebar elements styles
	style.mark_mini = redutil.table.merge(
		redutil.table.check(beautiful, "titlebar.mark") or {},
		{ size = 30, gap = 10, angle = 0 }
	)
	if not style.mark_mini or type(style.mark_mini) ~= "table" then
		style.mark_mini = {}
	end
	if not style.mark_mini.color then
		style.mark_mini.color = redutil.table.check(beautiful, "titlebar.base.color")
			or beautiful.color
	end
	style.mark_mini = ensure_mark_style(style.mark_mini)
	style.mark_compact = redutil.table.merge(
		style.mark_mini,
		{ size = 20, gap = 6, angle = 0.707 }
	)
	style.mark_compact = ensure_mark_style(style.mark_compact)
	style.icon_full = redutil.table.merge(
		redutil.table.check(beautiful, "titlebar.icon") or {},
		{ gap = 10 }
	)

	style.icon_compact = redutil.table.merge(
		redutil.table.check(beautiful, "titlebar.icon_compact") or style.icon_full,
		{ gap = 8 }
	)

	redtitle._index    = 1 -- choose default titlebar model

	-- titlebar setup for clients
	client.connect_signal(
		"request::titlebars",
		function(c)
			-- build titlebar and mouse buttons for it
			local menu_buttons = construct_menu_buttons(c)
			local move_buttons = construct_move_buttons(c)
			local all_buttons = construct_all_buttons(c, 1, 3)
			redtitle(c, style.base)

			local marks_mini = wibox.widget({
				line_action_button(c, style.mark_mini, function(cl) cl.minimized = true end),
				line_action_button(c, style.mark_mini, function(cl) cl.maximized = not cl.maximized end),
				line_action_button(c, style.mark_mini, function(cl) cl:kill() end),
				spacing = 6,
				layout  = wibox.layout.fixed.horizontal(),
			})
			-- Deja aire entre el rojo lateral y las 3 lineas centrales
			local hole_w = 3 * 16 + 2 * 6 + 2 * 10
			local gap_strip = focus_split_strip(c, style.mark_mini, hole_w)
			local left_title = mini_left_title_compact(c, style.mark_mini)
			local marks_layer = wibox.widget({
				left_title,
				marks_mini,
				nil,
				expand = "outside",
				layout = wibox.layout.align.horizontal,
			})
			marks_layer:buttons(awful.button({}, 3, function()
				client.focus = c
				c:raise()
				clientmenu:show(c)
			end))
			local base  = wibox.widget({
				nil,
				{
					gap_strip,
					marks_layer,
					layout = wibox.layout.stack,
				},
				nil,
				buttons = all_buttons,
				layout  = wibox.layout.align.horizontal,
			})

			-- build compact titlebar model
			local focus = redtitle.button.focus(c, style.icon_compact)
			focus:buttons(menu_buttons)

			local marks_compact = wibox.widget({
				{
					redtitle.mark.property(c, "floating", style.mark_compact),
					redtitle.mark.property(c, "sticky", style.mark_compact),
					redtitle.mark.property(c, "ontop", style.mark_compact),
					redtitle.mark.property(c, "below", style.mark_compact),
					spacing = style.mark_compact.gap,
					layout  = wibox.layout.fixed.horizontal,
				},
				{
					compact_focus(c, style.mark_compact),
					left = style.mark_compact.gap,
					layout = wibox.container.margin,
				},
				layout = wibox.layout.align.horizontal,
			})
			local compact = wibox.widget({
				{
					focus,
					{
						{
							nil,
							marks_compact,
							nil,
							expand = "outside",
							layout = wibox.layout.align.horizontal,
						},
						top = 3, bottom = 3, right = style.icon_compact.gap + 2, left = style.icon_compact.gap + 2,
						layout = wibox.container.margin,
					},
					{
						redtitle.button.property(c, "minimized", style.icon_compact),
						redtitle.button.property(c, "maximized", style.icon_compact),
						redtitle.button.close(c, style.icon_compact),
						spacing = style.icon_compact.gap,
						layout  = wibox.layout.fixed.horizontal()
					},
					buttons = move_buttons,
					layout  = wibox.layout.align.horizontal,

				},
				left = 4, right = 4,
				widget = wibox.container.margin
			})

			-- build titlebar model with control buttons
			local title = redtitle.label(c, style.iconic, true)
			title:buttons(move_buttons)

			local menu = redtitle.button.base("menu", style.icon_full)
			menu:buttons(menu_buttons)

			local iconic = wibox.widget({
				{
					{
						menu,
						redtitle.button.property(c, "floating", style.icon_full),
						redtitle.button.property(c, "sticky", style.icon_full),
						spacing = style.icon_full.gap,
						layout  = wibox.layout.fixed.horizontal()
					},
					top = 2, bottom = 2, left = 4,
					widget = wibox.container.margin
				},
				title,
				{
					{
						redtitle.button.property(c, "minimized", style.icon_full),
						redtitle.button.property(c, "maximized", style.icon_full),
						redtitle.button.close(c, style.icon_full),
						spacing = style.icon_full.gap,
						layout  = wibox.layout.fixed.horizontal()
					},
					top = 2, bottom = 2, right = 4,
					widget = wibox.container.margin
				},

				layout = wibox.layout.align.horizontal,
			})

			-- Set both models to titlebar
			redtitle.add_layout(c, nil, base, style.base.size)
			redtitle.add_layout(c, nil, compact, style.compact.size)
			redtitle.add_layout(c, nil, iconic, style.iconic.size)
			redtitle.switch(c, nil, redtitle._index)

			-- hide titlebar when window maximized
			if c.maximized_vertical or c.maximized then
				on_maximize(c)
			end

			c:connect_signal("property::maximized_vertical", on_maximize)
			c:connect_signal("property::maximized", on_maximize)
		end
	)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return titlebar
