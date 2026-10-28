-----------------------------------------------------------------------------------------------------------------------
--                                          RedFlat sensors popup (float)                                             --
-----------------------------------------------------------------------------------------------------------------------
-- Floating wibox that shows `sensors` output in a monospace list.
-- Pattern matches redflat.float.top_cpu / top_mem (show/hide/autohide).
-----------------------------------------------------------------------------------------------------------------------

local unpack = unpack or table.unpack

local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local timer = require("gears.timer")

local redutil = require("redflat.util")
local tr = require("redflat.util.lang").t

local M = {}

local function default_style()
	local style = {
		timeout       = 5,
		screen_gap    = 0,
		geometry      = { width = 520, height = 420 },
		border_margin = { 12, 12, 12, 12 },
		border_width  = 2,
		title_font    = "Sans 14 bold",
		body_font     = "Monospace 9",
		color         = { border = "#575757", text = "#aaaaaa", highlight = "#eeeeee",
		                  main = "#b1222b", bg = "#161616", wibox = "#202020" },
		shape         = nil,
	}
	style = redutil.table.merge(style, redutil.table.check(beautiful, "float.sensors") or {})
	return style
end

function M.new()
	local self = {}

	function self:init()
		local style = default_style()
		self.style = style

		-- Title
		local title = wibox.widget.textbox(tr("Sensors"))
		title:set_font(style.title_font)
		title:set_align("center")

		-- Body: monospace textbox with sensors output
		local body = wibox.widget.textbox()
		body:set_font(style.body_font)
		body:set_align("left")
		body:set_text("...")

		local area = wibox.layout.align.vertical()
		area:set_top(wibox.container.margin(title, 0, 0, 0, 8))
		area:set_middle(body)

		local layout = wibox.container.margin(area, unpack(style.border_margin))

		self.wibox = wibox({
			ontop        = true,
			bg           = style.color.wibox,
			border_width = style.border_width,
			border_color = style.color.border,
			shape        = style.shape,
		})
		self.wibox:set_widget(layout)
		self.wibox:geometry(style.geometry)

		redutil.float_autohide.attach(self, self.wibox, {
			hide = function() self:hide() end,
		})

		self.update_timer = timer({ timeout = style.timeout })
		self.update_timer:connect_signal("timeout", function() self:update() end)

		self._body = body
	end

	function self:update()
		awful.spawn.easy_async("sensors", function(output)
			if self._body then
				self._body:set_markup('<span color="' .. self.style.color.text .. '">'
					.. awful.util.escape(output or "")
					.. '</span>')
			end
		end)
	end

	function self:hide()
		if not self.wibox then return end
		self.wibox.visible = false
		self.update_timer:stop()
	end

	function self:show()
		if not self.wibox then self:init() end
		if self.wibox.visible then
			self:hide()
		else
			self:update()
			awful.placement.under_mouse(self.wibox)
			redutil.placement.no_offscreen(self.wibox, self.style.screen_gap,
				screen[awful.screen.focused()].workarea)
			redutil.float_autohide.stop(self)
			self.wibox.visible = true
			self.update_timer:start()
		end
	end

	return self
end

return M.new()
