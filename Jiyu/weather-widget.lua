-----------------------------------------------------------------------------------------------------------------------
--                                                   Weather widget                                                    --
-----------------------------------------------------------------------------------------------------------------------
-- Widget de clima usando wttr.in (sin API key)
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local weather = { widget = nil, timer = nil }

-- Función para obtener el clima desde wttr.in
local function get_weather(city)
	local cmd = string.format("curl -s 'wttr.in/%s?format=%%C%%20%%t'", city:gsub(" ", "%%20"))
	local handle = io.popen(cmd)
	if handle then
		local result = handle:read("*a")
		handle:close()
		return result:gsub("\n", ""):gsub("^%s*(.-)%s*$", "%1") -- Trim
	end
	return "N/A"
end

-- Crear el widget
function weather.new(args)
	args = args or {}
	local city = args.city or "Madrid"

	-- Crear textbox
	local widget = wibox.widget.textbox()
	widget:set_font("Sans 12")
	widget:set_align("center")

	-- Función de actualización
	local function update()
		local weather_data = get_weather(city)
		widget:set_markup(weather_data)
	end

	-- Actualizar inicialmente
	update()

	return widget
end

return weather
