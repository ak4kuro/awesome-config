-----------------------------------------------------------------------------------------------------------------------
--                                                    Theme switcher                                                  --
-----------------------------------------------------------------------------------------------------------------------
-- Cambia entre tema claro y oscuro modificando rc.lua y reiniciando AwesomeWM
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local L = require("Jiyu.locale").t

local theme_switcher = {}

local rc_path = awful.util.get_configuration_dir() .. "rc.lua"

function theme_switcher.toggle()
	local f = io.open(rc_path, "r")
	if not f then
		naughty.notify({ title = L("Error"), text = L("Could not read rc.lua"), timeout = 5 })
		return
	end
	local content = f:read("*a")
	f:close()

	local current = content:match("local USE_LIGHT_THEME%s*=%s*(%S+)")
	local new_value
	if current == "true" then
		new_value = "false"
	else
		new_value = "true"
	end

	local new_content = content:gsub(
		"local USE_LIGHT_THEME%s*=%s*%S+",
		"local USE_LIGHT_THEME = " .. new_value
	)

	f = io.open(rc_path, "w")
	if not f then
		naughty.notify({ title = L("Error"), text = L("Could not write rc.lua"), timeout = 5 })
		return
	end
	f:write(new_content)
	f:close()

	local theme_name = (new_value == "true") and L("Light") or L("Dark")
	naughty.notify({
		title = L("Theme changed"),
		text = L("Restarting to") .. " " .. theme_name .. "...",
		timeout = 2,
	})

	-- Sincronizar tema GTK con AwesomeWM
	awful.spawn.easy_async_with_shell(
		string.format('gsettings set org.gnome.desktop.interface color-scheme "%s" 2>/dev/null; '
			.. 'gsettings set org.gnome.desktop.interface gtk-theme "%s" 2>/dev/null || true',
			"prefer-" .. ((new_value == "true") and "light" or "dark"),
			(new_value == "true") and "Adwaita" or "Adwaita-dark"
		),
		function() end
	)

	gears.timer({
		timeout = 0.5,
		single_shot = true,
		callback = function()
			awesome.restart()
		end,
	}):start()
end

return theme_switcher
