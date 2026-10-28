-----------------------------------------------------------------------------------------------------------------------
--                                                 Location widget                                                    --
-----------------------------------------------------------------------------------------------------------------------
-- Widget de ubicación detectada por IP
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

local location = { widget = nil }

-- Función para obtener la ciudad desde IP
local function get_location()
	local handle = io.popen("curl -s 'https://ipinfo.io/city' 2>/dev/null")
	if handle then
		local result = handle:read("*a")
		handle:close()
		return result:gsub("\n", ""):gsub("^%s*(.-)%s*$", "%1") -- Trim
	end
	return "Unknown"
end

-- Crear el widget
function location.new()
	local widget = wibox.widget.textbox()
	widget:set_font("Sans 12")
	widget:set_align("center")

	-- Obtener ubicación inicial
	local city = get_location()
	widget:set_markup("<span color='" .. (beautiful.color and beautiful.color.text or "#000000") .. "'>" .. awful.util.escape(city) .. "</span>")

	return widget
end

return location
