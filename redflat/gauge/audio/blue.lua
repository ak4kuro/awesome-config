-----------------------------------------------------------------------------------------------------------------------
--                                        RedFlat volume indicator widget                                            --
-----------------------------------------------------------------------------------------------------------------------
-- Indicator with audio icon
-- color.on  = encendido (sin silenciar / mic activo)
-- color.off = apagado (silenciado)
-- icon_lerp: el color del icono interpola off→on según set_value (0–1), p. ej. brillo
-----------------------------------------------------------------------------------------------------------------------

local setmetatable = setmetatable
local unpack = unpack or table.unpack
local math = math

local wibox = require("wibox")
local beautiful = require("beautiful")

local redutil = require("redflat.util")
local svgbox = require("redflat.gauge.svgbox")
local reddash = require("redflat.gauge.graph.dash")
local input_level_icon = require("redflat.gauge.audio.input_level_icon")

local audio = { mt = {} }

local function hex_to_rgb(h)
	if not h or type(h) ~= "string" then
		return 160, 160, 160
	end
	h = h:gsub("#", "")
	if #h == 3 then
		return tonumber(h:sub(1, 1) .. h:sub(1, 1), 16),
			tonumber(h:sub(2, 2) .. h:sub(2, 2), 16),
			tonumber(h:sub(3, 3) .. h:sub(3, 3), 16)
	end
	if #h < 6 then
		return 160, 160, 160
	end
	return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

local function lerp_hex(a, b, t)
	t = math.max(0, math.min(1, t or 0))
	local r1, g1, b1 = hex_to_rgb(a)
	local r2, g2, b2 = hex_to_rgb(b)
	return string.format(
		"#%02x%02x%02x",
		math.floor(r1 + (r2 - r1) * t + 0.5),
		math.floor(g1 + (g2 - g1) * t + 0.5),
		math.floor(b1 + (b2 - b1) * t + 0.5)
	)
end

local function default_style()
	local style = {
		width      = 100,
		icon       = redutil.base.placeholder(),
		gauge      = reddash.new,
		dash       = {},
		dmargin    = { 10, 0, 0, 0 },
		icon_lerp        = false,
		icon_input_meter = false,
		icon_muted          = nil,
		icon_mute_at_zero   = false,
		icon_fill_from_bottom = false,
		color            = { on = "#b1222b", off = "#909090", icon = "#a0a0a0", mute = "#404040" },
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "gauge.audio.blue") or {})
end

local function resolve_on_off(style)
	local c = style.color or {}
	if c.on and c.off then
		return c.on, c.off
	end
	-- Compat: icon = color con señal, mute = color silenciado (convención antigua redflat)
	if c.icon and c.mute then
		return c.icon, c.mute
	end
	return c.on or "#b1222b", c.off or "#909090"
end

function audio.new(style)

	style = redutil.table.merge(default_style(), style or {})

	local on_c, off_c = resolve_on_off(style)
	local icon
	if style.icon_input_meter and type(style.icon) == "string" then
		icon = input_level_icon(style.icon, off_c, on_c, style.icon_muted, {
			mute_at_zero = style.icon_mute_at_zero,
			fill_from_bottom = style.icon_fill_from_bottom,
		})
	else
		icon = svgbox(style.icon)
	end

	local layout = wibox.layout.fixed.horizontal()
	layout:add(icon)

	local dash
	if style.gauge then
		dash = style.gauge(style.dash)
		layout:add(wibox.container.margin(dash, unpack(style.dmargin)))
	end

	local widg = wibox.container.constraint(layout, "exact", style.width)
	local last_value = 0

	function widg:set_value(x)
		if dash then
			dash:set_value(x)
		end
		last_value = x
		if style.icon_input_meter then
			icon:set_level(x)
		elseif style.icon_lerp then
			icon:set_color(lerp_hex(off_c, on_c, x))
		end
	end

	-- mute=true → silenciado / apagado (gris); mute=false → con señal (rojo)
	function widg:set_mute(mute)
		if style.icon_input_meter then
			icon:set_muted(mute)
			return
		end
		if style.icon_lerp then
			if mute then
				icon:set_color(off_c)
			else
				icon:set_color(lerp_hex(off_c, on_c, last_value))
			end
			return
		end
		icon:set_color(mute and off_c or on_c)
	end

	-- p. ej. widget batería llama set_alert; el medidor por icono no lo usa
	function widg:set_alert(_)
	end

	return widg
end

function audio.mt:__call(...)
	return audio.new(...)
end

return setmetatable(audio, audio.mt)
