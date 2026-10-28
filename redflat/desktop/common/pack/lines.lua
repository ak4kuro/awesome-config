-----------------------------------------------------------------------------------------------------------------------
--                                               RedFlat barpack widget                                              --
-----------------------------------------------------------------------------------------------------------------------
-- Group of indicators with progressbar, label and text in every line
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local wibox = require("wibox")
local beautiful = require("beautiful")

local redutil = require("redflat.util")
local dcommon = require("redflat.desktop.common")
local tooltip = require("redflat.float.tooltip")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local barpack = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
	local function default_style()
	local style = {
		label        = {},
		text         = {},
		show         = { text = true, label = true, tooltip = false },
		progressbar  = {},
		line         = { height = 20 },
		gap          = { text = 20, label = 20 },
		spacing      = 0, -- espacio vertical entre filas (flex.vertical)
		tooltip      = {},
		color        = {}
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "desktop.common.pack.lines") or {})
end


-- Create a new barpack widget
-----------------------------------------------------------------------------------------------------------------------
function barpack.new(num, style)

	local pack = {}
	style = redutil.table.merge(default_style(), style or {})
	local progressbar_style = redutil.table.merge(style.progressbar, { color = style.color })
	local label_style = redutil.table.merge(style.label, { color = style.color.gray })
	local text_style = redutil.table.merge(style.text, { color = style.color.gray })

	-- Todas las filas en un flex vertical para que `spacing` aplique también entre 1ª y 2ª
	--------------------------------------------------------------------------------
	pack.layout = wibox.layout.flex.vertical()
	pack.layout.spacing = style.spacing or 0
	local lines = {}

	for i = 1, num do
		lines[i] = {}

		-- bar
		local line_align = wibox.layout.align.horizontal()
		-- Asegura que el widget del medio (barra) expanda el ancho restante.
		line_align:set_expand("inside")
		line_align:set_forced_height(style.line.height)
		lines[i].bar = dcommon.bar.plain(progressbar_style)
		line_align:set_middle(lines[i].bar)

		-- label
		lines[i]._label_txt = ""
		lines[i].label = dcommon.textbox("", label_style)
		lines[i].label:set_width(0)
		lines[i].label_margin = wibox.container.margin(lines[i].label)
		line_align:set_left(lines[i].label_margin)

		-- value text
		lines[i].text = dcommon.textbox("", text_style)
		lines[i].text:set_width(0)
		lines[i].text_margin = wibox.container.margin(lines[i].text)
		line_align:set_right(lines[i].text_margin)

		-- tooltip
		if style.show.tooltip then
			lines[i].tooltip = tooltip({ objects = { line_align } }, style.tooltip)
		end

		pack.layout:add(line_align)
	end

	-- Setup functions
	--------------------------------------------------------------------------------

	function pack:set_values(value, index)
		lines[index].bar:set_value(value)
	end

	function pack:set_text(value, index)
		if style.show.text then
			lines[index].text:set_text(value)
			lines[index].text:set_width(value and text_style.width or 0)
			lines[index].text_margin:set_left(value and style.gap.text or 0)
		end

		if lines[index].tooltip then
			local lab = lines[index]._label_txt or ""
			if lab ~= "" then
				lines[index].tooltip:set_text(string.format("%s %s", lab, value))
			else
				lines[index].tooltip:set_text(value or "")
			end
		end
	end

	function pack:set_text_color(value, index)
		lines[index].text:set_color(value)
	end

	function pack:set_label_color(value, index)
		lines[index].label:set_color(value)
	end

	function pack:set_label(value, index)
		lines[index]._label_txt = value
		if style.show.label then
			lines[index].label:set_text(value)
			lines[index].label:set_width(value and label_style.width or 0)
			lines[index].label_margin:set_right(value and style.gap.label or 0)
		end
	end

	--------------------------------------------------------------------------------
	return pack
end

-- Config metatable to call barpack module as function
-----------------------------------------------------------------------------------------------------------------------
function barpack.mt:__call(...)
	return barpack.new(...)
end

return setmetatable(barpack, barpack.mt)
